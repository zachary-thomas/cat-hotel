extends SceneTree
const Cat=preload("res://scripts/world/voxel_cat.gd")
class RejectingStore extends RefCounted:
	var error_message:="Care test cannot save."
	func save_model(_model) -> bool: return false
var failures:=0
var actions: Array[String]=[]
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for index in range(4): await process_frame
func touch(point: Vector2, pressed: bool, index: int=0, canceled: bool=false) -> void:
	var event:=InputEventScreenTouch.new(); event.position=point; event.pressed=pressed; event.index=index; event.canceled=canceled
	root.push_input(event,true)
func drag(point: Vector2, relative: Vector2, index: int=0) -> void:
	var event:=InputEventScreenDrag.new(); event.position=point; event.relative=relative; event.velocity=relative*30; event.index=index
	root.push_input(event,true)
func mouse(point: Vector2, pressed: bool, emulated: bool=false) -> void:
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed; event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	if emulated: event.device=InputEvent.DEVICE_ID_EMULATION
	root.push_input(event,true)
func hit_point(stage) -> Vector2:
	var projected: Vector2=stage.camera.unproject_position(stage.cat.head.global_position)
	return projected*stage.size/Vector2(stage.viewport.size)
func screen_point(stage, local: Vector2) -> Vector2:
	return stage.get_global_transform_with_canvas()*local
func run() -> void:
	root.size=Vector2i(390,844); root.content_scale_size=Vector2i(390,844)
	var app=load("res://scenes/creative_hotel.tscn").instantiate()
	app.save_path="res://tmp/creative-care-"+str(Time.get_ticks_usec())
	root.add_child(app); await settle()
	app.set_process(false); app.world.set_process(false)
	app.ui.open_tab("Cats"); await settle()
	var portrait_button: Button
	for button in app.ui.find_children("*","Button",true,false):
		if button.tooltip_text.begins_with(str(app.model.state.cats[0].name)+" · "): portrait_button=button; break
	check(portrait_button!=null,"Collection retains a selectable cat portrait")
	if portrait_button!=null:
		var portrait_at: Vector2=portrait_button.get_global_rect().get_center()
		mouse(portrait_at,true); mouse(portrait_at,false)
	else: app.ui.open_cat_care(0)
	await settle()
	check(is_instance_valid(app.ui.care_screen) and app.ui.selected_cat==0,"Collection opens the selected cat's live care screen")
	var screen=app.ui.care_screen
	var stage=screen.stage
	stage.care_action.connect(func(kind: String): actions.append(kind))
	check(stage.tool=="pet" and screen.tool_buttons.pet.button_pressed,"Care starts with the pet tool selected")
	var point: Vector2=hit_point(stage)
	check(stage.cat_hit(point),"Projected cat head is a real hit target")
	var global: Vector2=screen_point(stage,point)
	var before: int=int(app.model.state.cats[0].bond)
	touch(global,true)
	check(stage.contact and stage.pointer==0 and app.soundscape.care_purr_active,"Real touch input pets the cat and starts purring")
	check(int(app.model.state.cats[0].bond)>before and screen.meter.value==app.model.state.cats[0].bond,"Petting updates saved friendship and its meter in place")
	var count: int=actions.size()
	touch(global,true,1); touch(global,false,1)
	check(stage.contact and stage.pointer==0 and actions.size()==count,"An extra finger cannot steal or duplicate the active touch")
	mouse(global,true,true); mouse(global,false,true)
	check(stage.contact and stage.pointer==0 and actions.size()==count,"Emulated mouse input cannot duplicate a touch")
	drag(global+Vector2(2,0),Vector2(2,0))
	app.ui.refresh()
	check(app.ui.care_screen==screen and screen.stage==stage and stage.contact,"UI refresh preserves the live stage and current contact")
	touch(Vector2(2,2),false)
	check(not stage.contact and stage.pointer==-2,"Release outside the stage clears touch contact")
	screen.select_tool("brush"); await settle()
	point=hit_point(stage); global=screen_point(stage,point)
	mouse(global,true)
	check(stage.contact and stage.pointer==-1 and stage.prop.visible,"Real mouse input brushes the cat with a visible brush")
	var motion:=InputEventMouseMotion.new(); motion.position=global+Vector2(3,0); motion.relative=Vector2(3,0); motion.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion,true)
	mouse(Vector2(2,2),false)
	check(not stage.contact and not stage.prop.visible,"Mouse release outside clears the brush and purr contact")
	count=actions.size()
	touch(screen_point(stage,Vector2(3,3)),true); touch(screen_point(stage,Vector2(3,3)),false)
	check(actions.size()==count and not stage.contact,"Touching room background does not award care")
	var shadow: MeshInstance3D
	for child in stage.cat.get_children():
		if child is MeshInstance3D and child.mesh is PlaneMesh: shadow=child; break
	check(shadow!=null,"Care cat has a shadow to exclude from petting")
	if shadow!=null:
		var shadow_at: Vector2=stage.camera.unproject_position(shadow.global_transform*Vector3(0.58,0,0))
		var shadow_local: Vector2=shadow_at*stage.size/Vector2(stage.viewport.size)
		check(stage._mesh_hit(shadow,stage.camera.project_ray_origin(shadow_at),stage.camera.project_ray_normal(shadow_at)),"The off-cat test point intersects the shadow")
		check(not stage.cat_hit(shadow_local),"The cat's floor shadow is not a petting target")
		count=actions.size(); before=int(app.model.state.cats[0].bond)
		app.model.state.time+=20
		touch(screen_point(stage,shadow_local),true); stage._process(1.2)
		check(not stage.contact and actions.size()==count and int(app.model.state.cats[0].bond)==before,"Stationary contact off the cat grants no care even after the reward cooldown")
		touch(screen_point(stage,shadow_local),false)
	touch(screen_point(stage,hit_point(stage)),true)
	touch(screen_point(stage,hit_point(stage)),false,0,true)
	check(not stage.contact and stage.pointer==-2,"A canceled touch always releases the cat")
	touch(screen_point(stage,hit_point(stage)),true)
	drag(screen_point(stage,Vector2(-20,-20)),Vector2(-100,-100))
	check(not stage.contact and stage.pointer==-2,"Dragging outside the stage cancels contact")
	touch(Vector2(2,2),false)
	for kind in stage.TOOLS:
		screen.select_tool(kind)
		check(stage.tool==kind and screen.tool_buttons[kind].button_pressed,"Tool selection updates "+kind)
		count=actions.size(); screen.use_button.pressed.emit()
		check(actions.size()==count+1 and actions.back()==kind,"Accessible activation engages "+kind)
		if kind in ["pet","brush"]: check(stage.contact,"Accessible affectionate action starts contact")
		elif kind=="cushion": check(stage.cushion.visible,"Cushion appears when offered")
		else: check(stage.prop.visible,"Selected toy appears for "+kind)
	for kind in ["wand","yarn"]:
		screen.select_tool(kind)
		var start: Vector2=stage.size*Vector2(0.45,0.55)
		var finish: Vector2=stage.size*Vector2(0.8,0.5)
		touch(screen_point(stage,start),true)
		drag(screen_point(stage,finish),finish-start)
		touch(screen_point(stage,finish),false)
		check(stage.prop.visible and not stage.held and stage._play_clock>0,"Dragging and releasing engages "+kind+" play")
		if kind=="yarn":
			check(stage.yarn_velocity.length()>0,"Flicking yarn launches the ball")
			for step in range(20): stage._process(0.1)
			check(absf(stage.prop.position.x)<=1.051 and stage.prop.position.z>=-0.551 and stage.prop.position.z<=0.901,"Rolling yarn remains inside the visible play area")
	screen.select_tool("pet")
	check(not stage.prop.visible and not stage.cushion.visible and not stage.contact,"Switching tools clears previous props and contact")
	screen.use_button.grab_focus(); count=actions.size()
	var key:=InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=true; root.push_input(key,true)
	key=InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=false; root.push_input(key,true)
	check(actions.size()==count+1 and stage.contact,"Keyboard activation provides equivalent petting")
	stage.suspend()
	screen.show_details(); await settle()
	check(is_instance_valid(screen.detail_panel) and not stage.contact,"Cat details open without leaving care or retaining touch contact")
	key=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=true; root.push_input(key,true)
	check(not is_instance_valid(screen.detail_panel) and app.ui.care_screen==screen,"Back from cat details returns to the same stage")
	touch(screen_point(stage,hit_point(stage)),true)
	stage.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not stage.contact and stage.pointer==-2,"Focus loss cancels the active gesture")
	touch(global,false)
	app.model.state.settings.motion=false; screen.update_progress()
	check(not stage.enabled_motion,"Care follows the reduced-motion setting")
	for kind in ["pet","brush","wand","yarn","cushion","box"]:
		screen.select_tool(kind); stage.use_selected_tool(); stage._process(0.1)
		var body_pose: Transform3D=stage.cat.body.transform
		var head_pose: Transform3D=stage.cat.head.transform
		var cat_position: Vector3=stage.cat.position
		var child_count: int=stage.scene.get_child_count()
		stage._process(0.3)
		check(stage.cat.body.transform==body_pose and stage.cat.head.transform==head_pose and stage.cat.position==cat_position,"Reduced motion gives a steady pose for "+kind)
		check(stage.scene.get_child_count()<=child_count,"Reduced motion emits no new particles for "+kind)
	screen.select_tool("pet")
	var real_store=app.store
	app.model.state.time+=20; app.store=RejectingStore.new()
	before=int(app.model.state.cats[0].bond)
	screen.use_button.pressed.emit()
	check(int(app.model.state.cats[0].bond)==before and not screen.message.text.is_empty(),"Failed care save rolls back friendship and reports the error")
	await settle()
	check(app.ui.care_screen==screen and screen.stage==stage,"Save failure leaves the same live care stage")
	stage.suspend(); app.store=real_store; app.save()
	app.blocked_save=true; app.save_error="Protected save"
	screen.use_button.pressed.emit()
	check(int(app.model.state.cats[0].bond)==before,"Blocked saving cannot change friendship through care controls")
	app.blocked_save=false; app.save_error=""; stage.suspend()
	screen._return_button.pressed.emit(); await settle()
	check(app.ui.active_tab=="Cats" and app.ui.care_screen==null,"Back returns to the collection")
	check(not app.soundscape.purr_player.playing,"Back stops purring immediately")
	for guest in app.model.state.cats: guest.known=true
	app.ui.refresh(); await settle()
	app.ui._cat_scroll.scroll_vertical=120; await settle()
	var collection_scroll: int=app.ui._cat_scroll.scroll_vertical
	app.ui.open_cat_care(17); await settle()
	check(app.ui.selected_cat==17,"A known cat can receive care even when absent from the hotel")
	app.ui.close_cat_care(); await settle()
	check(app.ui._cat_scroll.scroll_vertical==collection_scroll,"Back restores the collection scroll position")
	app.model.state.cats[17].known=false
	await hotel_selection(app)
	await layout_cases(app)
	await identities(app)
	app.soundscape.shutdown(); app.queue_free(); await settle()
	# Let the audio mix thread release stopped playback before ending the tree.
	await create_timer(0.15).timeout
	print("CREATIVE CARE: %d failures" % failures)
	quit(1 if failures else 0)

func hotel_selection(app) -> void:
	app.ui.open_tab("Hotel"); await settle()
	var world=app.world
	var original: Dictionary=world.actors
	for actor in original.values(): actor.hide()
	var guest=Cat.new(); world.add_child(guest); guest.build(Color("d99c51")); guest.set_process(false)
	guest.position=Vector3(8*world.UNIT,world.FLOOR,8*world.UNIT)
	world.actors={0:guest}; world.set_outside(false); world.focus_bounds(Rect2(6,6,4,4)); await settle()
	var at: Vector2=world.camera.unproject_position(guest.global_position+Vector3(0,0.65,0))
	check(world.pick_guest(at)==0,"Hotel picking selects a visible known guest")
	guest.hide(); check(world.pick_guest(at)==-1,"Hotel picking excludes hidden guests"); guest.show()
	world.actors={-1:guest}; check(world.pick_guest(at)==-1,"Hotel picking excludes staff")
	world.actors={17:guest}; check(world.pick_guest(at)==-1,"Hotel picking excludes unknown cats")
	world.actors={0:guest}
	var room: Dictionary=app.model.hotel().rooms[0]
	guest.position=Vector3((float(room.x)+float(room.w)/2)*world.UNIT,world.FLOOR,(float(room.y)+float(room.h)/2)*world.UNIT)
	world.set_outside(true)
	at=world.camera.unproject_position(guest.global_position+Vector3(0,0.65,0))
	check(world.pick_guest(at)==-1,"Exterior hotel picking excludes cats beneath closed roofs")
	world.set_outside(false)
	guest.position=Vector3(8*world.UNIT,world.FLOOR,8*world.UNIT)
	at=world.camera.unproject_position(guest.global_position+Vector3(0,0.65,0))
	check(app.ui.world_input_allowed(at),"Test guest is inside the hotel interaction area")
	touch(at,true); drag(at+Vector2(32,0),Vector2(32,0)); touch(at+Vector2(32,0),false)
	check(app.ui.care_screen==null,"Panning across a guest does not open care")
	at=world.camera.unproject_position(guest.global_position+Vector3(0,0.65,0))
	touch(at,true)
	check(app.ui.care_screen==null,"Guest care waits for tap release")
	touch(at,false); await settle()
	check(app.ui.care_screen!=null and app.ui.selected_cat==0,"Hotel tap release opens the correct guest")
	var camera_at: Vector3=world.camera.position
	app.ui.close_cat_care(); await settle()
	check(app.ui.active_tab=="Hotel" and world.camera.position==camera_at,"Back restores the hotel camera")
	world.actors=original; guest.queue_free()
	for actor in original.values(): actor.show()

func layout_cases(app) -> void:
	var capture: bool=OS.get_cmdline_user_args().has("--capture-care") and DisplayServer.get_name()!="headless"
	if capture: DirAccess.make_dir_recursive_absolute("res://tmp/care-captures")
	for dimensions in [Vector2i(360,640),Vector2i(390,844),Vector2i(1280,800)]:
		root.size=dimensions; root.content_scale_size=dimensions
		for text_scale in [1.0,1.5]:
			app.model.state.settings.ui_text_scale=text_scale
			for theme in range(4):
				app.model.state.current_hotel=theme
				app.ui.open_tab("Cats"); await settle()
				app.ui.open_cat_care(theme); await settle()
				var screen=app.ui.care_screen
				var safe: Rect2=screen.get_global_rect().grow(1)
				for control in screen.tool_buttons.values()+[screen.stage,screen.use_button,screen._return_button]:
					check(safe.encloses(control.get_global_rect()),"Care controls fit %s at %d%% in theme %d: %s %s within %s" % [dimensions,roundi(text_scale*100),theme,control.name,control.get_global_rect(),safe])
				check(screen.stage.size.y>=125,"The cat stage remains usable at "+str(dimensions))
				if capture:
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://tmp/care-captures/care-%dx%d-%d-theme%d.png" % [dimensions.x,dimensions.y,roundi(text_scale*100),theme])
				app.ui.close_cat_care(); await settle()
	root.size=Vector2i(390,844); root.content_scale_size=Vector2i(390,844)
	app.ui.safe_area_override=Rect2(0,28,390,790)
	app.ui.open_cat_care(0); await settle()
	var safe_screen=app.ui.care_screen
	check(app.ui.safe_area_override.encloses(safe_screen.get_global_rect()),"Care respects phone safe-area insets")
	for control in safe_screen.tool_buttons.values()+[safe_screen.stage,safe_screen.use_button]:
		check(app.ui.safe_area_override.encloses(control.get_global_rect()),"Interactive care controls remain inside the phone safe area")
	app.ui.close_cat_care(); app.ui.safe_area_override=Rect2()

func identities(app) -> void:
	for identity in range(18):
		app.model.state.cats[identity].known=true
		app.ui.open_cat_care(identity); await settle()
		var screen=app.ui.care_screen
		check(screen.cat_index==identity and screen.stage.cat.get_meta("cat_index")==identity,"Care preserves cat identity %d" % identity)
		check(screen.stage.cat.coat==Color(screen.Content.COATS[identity]),"Care uses the authored coat for cat %d" % identity)
		var named:=false
		for label in screen.find_children("*","Label",true,false):
			if label.text==screen.Content.CAT_NAMES[identity]: named=true
		check(named and screen._portrait.texture!=null,"Care keeps the name and portrait for cat %d" % identity)
		check(screen.stage.cat_hit(hit_point(screen.stage)),"Each cat identity has a hittable head")
		app.ui.close_cat_care(); await settle()
