extends SceneTree
const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const Layout = preload("res://scripts/core/furniture_layout.gd")
const F = preload("res://tests/fixtures/build_mode_fixtures.gd")
const Metrics = preload("res://scripts/ui/build_metrics.gd")
var failures: int = 0
class FailingStore:
	extends RefCounted
	var error_message := "Simulated furniture save failure"
	func save_model(_model) -> bool: return false
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	check(ResourceLoader.exists("res://scripts/world/furniture_renderer.gd"),"Instance furniture renderer exists")
	if failures: quit(1); return
	var Renderer = load("res://scripts/world/furniture_renderer.gd")
	var builder = load("res://scripts/world/room_builder.gd").new()
	root.add_child(builder)
	var renderer = Renderer.new()
	renderer.builder = builder
	root.add_child(renderer)
	for definition in Catalog.all_items(true):
		var instance: Dictionary = F.placed(definition.id,"f1",0,0)
		renderer.sync(F.suite(),[instance])
		check(renderer.objects.size()==1,"One object root per UID")
		var bounds: AABB = renderer.object_bounds("f1")
		check(bounds.size.x<=definition.footprint.x*0.55 and bounds.size.z<=definition.footprint.y*0.55,"Furniture mesh stays in its declared footprint: "+str(definition.id))
	var items = [F.placed("mat","f1",0,0),F.placed("box","f2",4,0)]
	renderer.sync(F.regular(),items)
	var identity: int = renderer.objects.f1.get_instance_id()
	items[0].x = 1
	renderer.sync(F.regular(),items)
	check(renderer.objects.f1.get_instance_id()==identity,"Moving reuses existing geometry")
	var ghost = F.placed("scratch","draft:one:1",4,3)
	renderer.show_ghost(F.regular(),ghost,{"ok":true})
	check(renderer.objects.size()==2,"Ghost never becomes a committed instance")
	renderer.clear_ghost()
	check(renderer.objects.size()==2,"Cancel removes only ghost")
	renderer.free()
	builder.free()
	await test_makeover_flow()
	print("BUILD MODE TESTS: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	quit(1 if failures else 0)

func test_makeover_flow() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	var path := "res://tmp/makeover-test-%d" % Time.get_ticks_usec()
	app.save_path=path; root.add_child(app); await process_frame
	app.start_game(); app.active=false; app.model.settings.motion=false
	app.world.set_motion_enabled(false)
	app._rebuild_world()
	check(app.world.ensure_cat(0).get_meta("resident_room",-1)==0 and app.world.ensure_cat(0).routine[0].action=="sleep","Structural rebuild reinstates resident routes")
	for actor in app.world.actors:
		if actor.get_meta("resident_room",-1)<0: continue
		check(actor.routine[0].action=="sleep","Residents start at their bed pose")
		check_guarded_segments(actor.routine)
	var visitor = app.world.ensure_cat(0)
	visitor.place_at(Vector3(0,0.24,5.8))
	app.world.guest_visit(app.model,0)
	check_guarded_segments(visitor.routine)
	var panel = app.build_panel; panel.open(0); await process_frame
	var build_body: Label
	for child in panel.content.get_children():
		if child is Label:
			build_body = child
			break
	check(build_body != null and build_body.get_theme_font_size("font_size") >= roundi(16 * panel._font_scale),"Build body copy is at least 16 phone units")
	app.model.settings.watch=true; app.world.apply_life(app.model)
	check(app.world.follow_cat==-1 and not app.world.exterior_view,"Build camera takes precedence over Watch and exterior settings")
	app.model.settings.watch=false
	var before: Dictionary = app.model.serialize()
	panel.preview_item("scratch")
	check(panel.confirm_button.icon!=null and panel.get_node("BuildActions/CancelFurniture").icon!=null,"Furniture placement has check and cancel icons")
	check(panel.confirm_button.text=="Place · 140","Place keeps the exact purchase price visible")
	check(panel.confirm_button.accessibility_name.contains("Place") and panel.get_node("BuildActions/CancelFurniture").accessibility_name.contains("Cancel"),"Icon actions retain readable accessibility names")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(360,640); app.model.settings.build_text_scale=1.5; panel._resize()
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/furniture-check-valid-360x640.png")
	var valid_ghost: Dictionary=panel.ghost.duplicate(true)
	panel.ghost.x=-1; panel._check_ghost(); panel._update_action()
	check(panel.confirm_button.disabled,"Invalid furniture placement disables the checkmark")
	panel.confirm()
	check(app.model.coins_units==before.coins_units and app.model.furniture.serialize()==before.furniture,"An invalid checkmark action cannot buy furniture")
	if DisplayServer.get_name()!="headless":
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/furniture-check-invalid-360x640.png")
	panel.ghost=valid_ghost; panel._check_ghost(); panel._update_action(); panel.confirm()
	check(app.model.coins_units==before.coins_units-140*app.model.UNIT and app.model.furniture.room_items(0,0).any(func(value): return value.item=="scratch"),"Place immediately charges and saves one furniture copy")
	var after_place: Dictionary=app.model.serialize()
	panel._select_room(1)
	check(panel.selected_room==1 and not panel.session.dirty(),"Saved edits allow an immediate cross-room switch")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not panel.visible and not app.world.build_mode and app.ui.tab=="Hotel","Android Back exits Build directly after saved actions")
	panel.open(0)
	var real_store=app.store; app.store=FailingStore.new()
	var failure_before: Dictionary=app.model.serialize()
	panel.preview_item("flowers")
	var failed_uid: String=str(panel.ghost.uid)
	panel.confirm()
	check(app.model.serialize()==failure_before,"A failed immediate save rolls back wallet and instances atomically")
	check(not panel.ghost.is_empty() and str(panel.ghost.uid)==failed_uid and is_instance_valid(app.world.room_builder.renderer(0)._ghost),"A failed save keeps the positioned ghost available to retry")
	check(not panel.confirm_button.disabled and panel.confirm_button.text=="Place · 160","A valid preview can retry the same quoted Place after a save failure")
	if DisplayServer.get_name()!="headless":
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/task4-build-save-failure-360x640-150.png")
	app.store=real_store; app.save_error=""; panel.cancel()
	var earned_units: int=77*int(app.model.UNIT)
	app.model.coins_units+=earned_units
	panel._history(false)
	check(app.model.coins_units==before.coins_units+earned_units and not app.model.furniture.room_items(0,0).any(func(value): return value.item=="scratch"),"Undo refunds the saved purchase while preserving later earnings")
	panel._history(true)
	check(app.model.coins_units==after_place.coins_units+earned_units and app.model.furniture.room_items(0,0).any(func(value): return value.item=="scratch"),"Redo reapplies the same purchase without losing later earnings")
	await test_phone_catalogue_and_placement(app,panel)
	for resolution in [Vector2i(360,640),Vector2i(360,800),Vector2i(390,844),Vector2i(430,932),Vector2i(768,1024),Vector2i(1280,800)]:
		root.size=resolution
		app.model.settings.build_text_scale=1.5
		panel.browse=false; panel._resize()
		await process_frame; await process_frame
		var viewport: Rect2 = panel.get_viewport_rect()
		var actions: Rect2 = panel.actions.get_global_rect()
		var play: Button=panel.get_node("BuildHeader/CloseBuilder")
		check(panel.get_node("BuildHeader").get_global_rect().grow(1).encloses(play.get_global_rect()),"Play remains a single-line button inside the header at "+str(resolution))
		check(viewport.grow(0.1).encloses(actions),"Fixed actions fit at %s: viewport %s, actions %s" % [resolution,viewport,actions])
		check(panel.panel.get_global_rect().end.x<=viewport.end.x+1,"Panel never overflows the phone width at "+str(resolution))
		check(panel.input_context().world_rect.size.y>=viewport.size.y*0.5-1 or panel.metrics.wide,"Placement leaves half the phone height visible")
		for button in panel.actions.get_children(): check(button.size.y>=panel.metrics.min_target-1,"Primary buttons meet phone touch size")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tmp/build-%dx%d-150.png" % [resolution.x,resolution.y])
		panel.browse=true; panel._refresh(); await process_frame; await process_frame
		check(panel.panel.get_global_rect().end.x<=viewport.end.x+1,"Catalogue fits at large text "+str(resolution))
		if DisplayServer.get_name()!="headless" and resolution==Vector2i(360,640):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tmp/build-catalogue-360x640-150.png")
	panel.browse=false; panel._refresh()
	panel.preview_item("plant")
	if DisplayServer.get_name()!="headless":
		root.size=Vector2i(360,640); panel._resize()
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		check(panel.panel.get_global_rect().grow(1).encloses(panel.status.get_global_rect()),"Large-text placement feedback stays visible above the action bar")
		root.get_texture().get_image().save_png("res://tmp/build-placement-360x640-150.png")
	var room_before: Array = panel.session.instances.duplicate(true)
	panel.cancel()
	check(panel.session.instances==room_before,"Cancel object preview leaves the makeover unchanged")
	check(not is_instance_valid(app.world.room_builder.renderer(0)._ghost),"Cancel removes rendered preview geometry")
	panel.close()
	if DisplayServer.get_name()!="headless":
		app.model.coins=999999999
		panel.open(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/build-no-room-large-wallet-360x640-150.png")
		panel.close()
	app.queue_free(); await process_frame; await create_timer(0.1).timeout
	preload("res://scripts/core/save_journal.gd").new(path).clear()
	preload("res://scripts/core/build_draft_store.gd").new(path).clear()

func test_phone_catalogue_and_placement(app, panel) -> void:
	root.size=Vector2i(360,640)
	for text_scale in [1.0,1.5]:
		app.model.settings.build_text_scale=text_scale
		panel.cancel(); panel.browse=true; panel._refresh()
		await process_frame; await process_frame
		var grid: GridContainer=panel.find_child("FurnitureGrid",true,false)
		check(grid!=null,"Furniture uses one whole-card grid at %.0f%%" % (text_scale*100.0))
		var cards: Array[Node]=panel.find_children("FurnitureCard_*","Button",true,false)
		check(cards.size()>=3,"Expanded browse exposes every matching furniture card")
		if text_scale==1.0:
			check(panel.metrics.browse_rect.position.y<=panel.metrics.history_rect.end.y+panel.metrics.gap+1,"Normal browse expands below history so the first complete card row is visible")
		if grid!=null:
			check(grid.columns==(2 if text_scale<1.5 else 1),"Furniture cards reflow for %.0f%% text" % (text_scale*100.0))
		if not cards.is_empty():
			var card: Button=cards[0]
			check(card.custom_minimum_size.y>=148.0*panel.metrics.unit,"Furniture art and copy share a large whole-card target")
			check(card.find_child("FurnitureArt",true,false)!=null,"Furniture thumbnail is inside the tappable card")
			var scroll: ScrollContainer=panel.find_child("BuildScroll",true,false)
			scroll.scroll_vertical=roundi(scroll.get_v_scroll_bar().max_value)
			await process_frame; await process_frame
			check(scroll.get_global_rect().grow(1).intersects(cards[-1].get_global_rect()),"Expanded browse can scroll to the final furniture card")
			scroll.scroll_vertical=0
			await process_frame; await process_frame
			if text_scale==1.0:
				for index in range(mini(2,cards.size())):
					var price: Control=cards[index].find_child("FurniturePrice",true,false)
					check(price!=null and scroll.get_global_rect().end.y-cards[index].get_global_rect().end.y>=8*panel.metrics.unit,"Initial normal browse shows the complete first furniture row including prices")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tmp/task4-build-catalogue-360x640-%d.png" % int(text_scale*100.0))
		var before: Dictionary=app.model.serialize()
		panel.preview_item("perch")
		await process_frame; await process_frame
		check(app.model.serialize()==before,"Selecting a catalogue card never purchases")
		check(not panel.browse,"Selection collapses browse into placement")
		check(panel.confirm_button.text.contains("150"),"Place displays the actual perch quote")
		check(panel.confirm_button.text.begins_with("Place ·"),"Furniture purchase action is labelled Place")
		check(panel.confirm_button.accessibility_name.contains("150 Cat Coins"),"Paid placement names the exact Cat Coin cost")
		var tray: Control=panel.find_child("SelectedFurnitureTray",true,false)
		var tray_copy: String=""
		if tray!=null:
			for label in tray.find_children("*","Label",true,false): tray_copy+=label.text+"\n"
		check(tray_copy.contains("Miso loves"),"Selected tray prioritizes a known cat preference hint")
		check(not tray_copy.contains("Place · 150"),"Selected metadata does not duplicate the pinned Place price")
		var safe: Rect2=scaled_rect(Metrics.safe_area(panel),Metrics.phone_scale(panel))
		for name in ["CloseBuilder","UndoBuild","RedoBuild","RotateFurniture","AdjustFurniture","CancelFurniture","PlaceFurniture"]:
			var control: Control=panel.find_child(name,true,false)
			check(control!=null,"%s is available during placement" % name)
			if control!=null: check(safe.grow(1).encloses(scaled_rect(control.get_global_rect(),Metrics.phone_scale(panel))),"%s remains visible at %.0f%% text" % [name,text_scale*100.0])
		var rotate: Button=panel.find_child("RotateFurniture",true,false)
		var adjust: Button=panel.find_child("AdjustFurniture",true,false)
		var cancel_button: Button=panel.find_child("CancelFurniture",true,false)
		check(rotate!=null and rotate.text.contains("Rotate"),"Rotate uses a readable label")
		check(adjust!=null and adjust.text.contains("Adjust"),"Nudge controls open from a readable Adjust label")
		check(cancel_button!=null and cancel_button.text.contains("Cancel"),"Cancel uses a readable label")
		var world: Rect2=scaled_rect(panel.input_context().world_rect,Metrics.phone_scale(panel))
		check(world.size.y>=safe.size.y*0.5-1,"Placement world keeps at least half the physical safe height at %.0f%% text" % (text_scale*100.0))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tmp/task4-build-placement-360x640-%d.png" % int(text_scale*100.0))
	var wallet_units: int=app.model.coins_units
	app.model.coins_units=0; panel._check_ghost(); panel._refresh()
	check(panel.confirm_button.disabled and panel.validity.message.contains("150"),"Unaffordable selection stays positioned and reports the exact shortfall")
	if DisplayServer.get_name()!="headless":
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/task4-build-unaffordable-360x640-150.png")
	app.model.coins_units=wallet_units; panel.cancel()

func scaled_rect(rect: Rect2, scale: float) -> Rect2:
	return Rect2(rect.position*scale,rect.size*scale)

func check_guarded_segments(routine: Array) -> void:
	for index in range(1,routine.size()):
		var step: Dictionary = routine[index]
		if step.has("guard"):
			check(step.guard.call(routine[index-1].position,step.position),"Every guarded segment starts and ends on a reachable interior path")
