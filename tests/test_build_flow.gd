extends SceneTree
const Interior=preload("res://scripts/core/furniture_layout.gd")
const Shared=preload("res://scripts/core/shared_layout.gd")
var failures := 0
class FailingStore:
	extends RefCounted
	var error_message := "Simulated save failure"
	func save_model(_model) -> bool: return false
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	var path := "res://tmp/continuous-build-%d" % Time.get_ticks_usec()
	app.save_path=path
	root.add_child(app)
	await process_frame
	app.start_game(); app.active=false
	var panel = app.build_panel
	panel.open(0)
	var balance: int = app.model.coins_units
	panel.preview_item("scratch"); panel.confirm()
	check(app.model.furniture.room_items(0,0).any(func(value): return value.item=="scratch"),"Place immediately saves furniture")
	check(app.model.coins_units==balance-140*app.model.UNIT,"Place spends the displayed price once")
	panel._select_room(1)
	check(panel.selected_room==1,"Editing another room needs no checkout")
	var scratch: Dictionary=app.model.furniture.room_items(0,0).filter(func(value): return value.item=="scratch")[0]
	panel._select_room(0); panel._select_object(scratch.uid)
	var slot := find_slot(app,1,"scratch")
	var camera_before: Vector3=app.world.camera_target
	tap_cell(app,1,slot)
	check(panel.selected_room==1 and panel.source_room==0 and panel.validity.ok,"A selected object can target another room directly")
	check(app.world.camera_target.is_equal_approx(camera_before),"Cross-room placement preserves the player's camera")
	panel.confirm()
	check(app.model.furniture.room_items(0,1).any(func(value): return value.uid==scratch.uid),"Cross-room Move preserves ownership without a storage step")
	check(app.model.coins_units==balance-140*app.model.UNIT,"Moving furniture between rooms is free")
	panel._history(false)
	check(app.model.furniture.room_items(0,0).any(func(value): return value.uid==scratch.uid),"Undo restores the source room")
	panel._history(true)
	check(app.model.furniture.room_items(0,1).any(func(value): return value.uid==scratch.uid),"Redo restores the destination room")
	panel.close(); panel.open()
	check(panel.session==null and panel.browse,"Build opens a catalogue without asking for a room")
	panel.preview_item("plant")
	tap_cell(app,-2,Vector2i(19,39))
	check(panel.selected_room==-2 and panel.validity.ok,"Choose furniture first and place it directly on lobby floor")
	panel.confirm()
	check(app.model.furniture.room_items(0,-2).size()==1,"Lobby furniture is committed through the same Place flow")
	check(app.world.room_builder.renderer(-2).objects.size()==1,"Saved lobby furniture is rendered")
	var shared: Dictionary=app.model.furniture.room_items(0,-2)[0]
	panel._select_object(shared.uid); panel.store_selected()
	check(app.model.furniture.stored_items().any(func(value): return value.uid==shared.uid),"Lobby furniture can be stored")
	panel.preview_item("plant",shared.uid); tap_cell(app,0,find_slot(app,0,"plant")); panel.confirm()
	check(app.model.furniture.room_items(0,0).any(func(value): return value.uid==shared.uid),"Stored lobby furniture can be reused in a guest room for free")
	app.model.hotels[0].wings=1; app.model.hotels[0].purchases=4; app.model.coins=5000
	app.model.life.sync_discoveries(app.model.discovered_cats())
	app._rebuild_world(); panel._select_room(1)
	var original: Array=app.model.furniture.room_items(0,1)
	panel.copy_room()
	check(panel.placing and panel.blueprint_placing,"Copy room opens a movable blueprint directly")
	panel.candidate={"kind":"regular","x":0,"y":6,"rotation":0}; panel._update_validity()
	check(panel.validity.ok and panel.blueprint_cost==590,"Blueprint shows shell plus paid furniture total")
	if DisplayServer.get_name()!="headless":
		panel._refresh(); await process_frame; await process_frame; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/build-blueprint-360x640.png")
	var before_copy: Dictionary=app.model.serialize()
	var real_store=app.store; app.store=FailingStore.new(); panel.confirm()
	check(app.model.serialize()==before_copy and panel.placing,"Failed blueprint save rolls back shell, furniture and payment while retaining preview")
	app.store=real_store; app.save_error=""; panel.confirm()
	check(app.model.room_count(0)==3 and app.model.coins==4410,"One Paste pays once and creates a complete room")
	check(app.model.furniture.room_items(0,1)==original,"Copying preserves the original room")
	var cloned: Array=app.model.furniture.room_items(0,2)
	for instance in cloned: check(not original.any(func(value): return value.uid==instance.uid),"Copied room owns distinct furniture instances")
	app.model.coins+=17
	panel._history(false)
	check(app.model.room_count(0)==2 and app.model.coins==5017,"Undo removes the whole copied room, refunds it and preserves income")
	panel._history(true)
	check(app.model.room_count(0)==3 and app.model.coins==4427,"Redo recreates the complete room at its original price")
	panel._select_room(2); panel.copy_room(); panel.candidate={"kind":"regular","x":6,"y":6,"rotation":2}; panel._update_validity()
	app.model.coins=0; panel._update_validity(); panel._refresh()
	check(not panel.validity.ok and panel.confirm_button.disabled,"Unaffordable blueprint cannot be placed")
	panel.cancel()
	panel.close()
	check(not panel.visible and not app.world.build_mode and app.ui.tab=="Hotel","Leaving Build returns straight to play")
	check(panel.review=="","Leaving Build never opens an Apply or discard dialog")
	# History survives changing destinations; jobs must follow the edited hotel.
	app.model.hotels[1].owned=true
	check(app.model.furniture.ensure_rooms(app.model,1),"A second owned hotel has canonical furniture")
	app.model.life.sync_discoveries(app.model.discovered_cats())
	app.model.grounds.hotels[0].maid=true; app.model.grounds.hotels[0].dirty[0]=true
	app.model.grounds.layout_changed(app.model,0)
	var old_target: Vector2=app.model.grounds.room_spot(0,app.model,0)
	check(app.perform_layout("move_room",{"hotel":0,"room":0,"kind":"regular","x":6,"y":6,"rotation":2}).ok,"Room move starts cross-hotel history fixture")
	app.model.current_hotel=1
	check(app.undo_build().ok,"Undo can reverse a build in a previously visited hotel")
	var job: Dictionary=app.model.grounds.hotels[0].maid_job
	check(not job.is_empty() and Vector2(job.path[-1][0],job.path[-1][1]).is_equal_approx(old_target),"Cross-hotel Undo replans housekeeping in the changed hotel")
	var restored=preload("res://scripts/core/hotel_model.gd").new()
	check(restored.restore(app.model.serialize()),"Mixed room and shared edits restore as a valid save")
	# Rate calculation includes shared comfort exactly once, independently of rooms.
	var base_rate: int=restored.hotel_rate(0)
	var quality_items: Array=[]
	for id in ["canopy_bed","adventure_tree","cloud_sofa","flowers"]: quality_items.append({"uid":id,"item":id,"hotel":0,"room":-2,"x":0,"y":0,"rotation":0})
	var bonus: int=preload("res://scripts/core/room_quality.gd").summarize(quality_items).income
	restored.furniture.state.instances.append_array(quality_items)
	check(bonus>0 and restored.hotel_rate(0)==base_rate+bonus,"Shared quality income matches the Build panel benefit")
	app.soundscape.shutdown()
	app.queue_free(); await process_frame
	preload("res://scripts/core/save_journal.gd").new(path).clear()
	preload("res://scripts/core/build_draft_store.gd").new(path).clear()
	print("BUILD FLOW TESTS: %s (%d failures)" % ["PASS" if failures==0 else "FAIL",failures])
	quit(1 if failures else 0)

func find_slot(app, room: int, item: String) -> Vector2i:
	var data: Dictionary=Shared.data(app.model.hotels,0) if room==-2 else app.model.hotels[0].layout[room]
	var items: Array=app.model.furniture.room_items(0,room)
	var dims: Vector2i=Interior.dimensions(data.kind)
	for y in range(dims.y):
		for x in range(dims.x):
			var value: Dictionary={"uid":"preview","item":item,"hotel":0,"room":room,"x":x,"y":y,"rotation":0}
			if Interior.validate(data,items+[value],room>=0).ok: return Vector2i(x,y)
	check(false,"A valid test placement exists for "+item)
	return Vector2i(-1,-1)

func tap_cell(app, room: int, cell: Vector2i) -> void:
	var data: Dictionary=Shared.data(app.model.hotels,0) if room==-2 else app.model.hotels[0].layout[room]
	var point: Vector3=Interior.local_to_world(data,Vector2(cell)+Vector2(0.1,0.1))
	app.build_panel.world_tapped(app.world.camera.unproject_position(point))
