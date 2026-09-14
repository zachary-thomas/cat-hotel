extends SceneTree
const Model = preload("res://scripts/core/hotel_model.gd")
const Grounds = preload("res://scripts/core/grounds_model.gd")
var failures: int = 0
var app
var save_key: String

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/"+name+".png")

func click(control: Control) -> void:
	await process_frame
	var point: Vector2 = control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event = InputEventMouseButton.new()
		event.position = point
		event.pressed = pressed
		event.button_index = MOUSE_BUTTON_LEFT
		root.push_input(event,true)
		await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	save_key = "res://tmp/views-"+str(Time.get_ticks_usec())
	app = load("res://scenes/main.tscn").instantiate()
	app.save_path = save_key
	root.add_child(app)
	await process_frame
	app.start_game()
	app.ui.toast_timer = 0
	app.ui.toast_label.hide()
	var world = app.world
	var shell = world.shell
	var origin: Vector2 = world.camera.unproject_position(Vector3.ZERO)
	var dx: Vector2 = world.camera.unproject_position(Vector3.RIGHT)-origin
	var dz: Vector2 = world.camera.unproject_position(Vector3.BACK)-origin
	check(world.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and absf(dx.length()-dz.length()) < 0.001 and absf(dx.x+dz.x) < 0.001,"The hotel uses a symmetric orthographic isometric camera")
	check(absf(absf(dx.y/dx.x)-0.57735) < 0.001,"The isometric ground axes have the expected 30 degree screen angle")
	check(shell.doors.size() == 5 and not shell.exterior.visible,"Starter suites and hotel entrances have working doors")
	await capture("50-isometric-inside")
	app.ui.open_route("View", "Hotel")
	await click(app.ui.view_button)
	check(world.exterior_view and shell.exterior.visible and app.ui.tab == "Hotel","The view button shows the complete hotel and offers a return inside")
	await capture("51-isometric-outside")
	check(app.activity.repair_markers.all(func(marker): return not marker.visible),"Exterior view hides repair controls behind the roof")
	check(not shell.doors[0].frame.visible and shell.doors[2].frame.visible,"Exterior view hides interior doors while keeping entrance doors")
	world._select(world.camera.unproject_position(Vector3(2.9,0.2,-6.75)))
	check(app.ui.tab == "Hotel","Tapping the exterior cannot select rooms through the roof")
	var restored = Model.new()
	check(restored.restore(app.model.serialize()) and restored.settings.exterior,"The chosen view survives saving")
	var legacy: Dictionary = app.model.serialize()
	legacy.settings.erase("exterior")
	var migrated = Model.new()
	check(migrated.restore(legacy) and not migrated.settings.exterior,"Existing saves keep the interior view on migration")
	app.change_setting("watch",true)
	check(not world.exterior_view,"Watch mode reveals the followed cat")
	app.change_setting("watch",false)
	check(world.exterior_view,"Leaving Watch restores the chosen exterior view")
	app.ui.open_route("View", "Hotel")
	await click(app.ui.view_button)
	check(not world.exterior_view and shell.doors[0].frame.visible,"The inside button restores the room doors")
	world.focus_zone(0)
	var actor_positions: Array = world.actors.map(func(actor): return actor.position)
	for actor in world.actors: actor.position = Vector3(20,0,20)
	world.neighborhood.manager.position = Vector3(20,0,20)
	world.neighborhood.maid.position = Vector3(20,0,20)
	world.motion_enabled = true
	check(shell.select_door(world.camera.unproject_position(shell.doors[0].position+Vector3(0,0.8,0))),"Room doors can be tapped directly")
	shell._process(0.1)
	check(shell.doors[0].pivot.rotation.y < -0.1 and shell.doors[0].pivot.rotation.y > -PI*0.52,"Tapped doors swing open over time")
	shell._process(5)
	check(not shell.doors[0].open and is_zero_approx(shell.doors[0].pivot.rotation.y),"Doors close after cats have passed and the tap hold expires")
	world.actors[0].position = shell.doors[0].position
	shell._process(0.5)
	check(shell.doors[0].open,"Approaching cats automatically open a door")
	world.motion_enabled = false
	world.actors[0].position = Vector3(20,0,20)
	shell._process(0.01)
	check(is_zero_approx(shell.doors[0].pivot.rotation.y),"Reduced motion keeps functional doors without swing animation")
	for i in range(actor_positions.size()): world.actors[i].position = actor_positions[i]
	var bounds: Rect2 = world.navigation_bounds()
	for zoom in [8.0,18.0,10000.0]:
		world.set_zoom(zoom)
		check(world.camera.size <= world.overview_zoom+0.001,"Zoom out stops at the full-property overview")
		for drag in [Vector2(1e6,0),Vector2(-1e6,0),Vector2(0,1e6),Vector2(0,-1e6)]:
			world._pan(drag)
			var stopped: Vector3 = world.camera_target
			world._pan(drag)
			check(world.camera_target.distance_to(stopped)<0.001,"Repeated dragging stops at the property boundary")
			check(bounds.grow(0.001).has_point(Vector2(world.camera_target.x,world.camera_target.z)),"Camera cannot pan beyond the street or into locked land")
	world.set_zoom(14)
	var before_pan: Vector3 = world.camera_target
	world._pan(Vector2(80,40))
	check(world.camera_target.distance_to(before_pan)>0.1,"Zooming in still allows useful map exploration")
	world.reset_camera()
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	world.handle_input(wheel)
	check(is_equal_approx(world.camera.size,world.overview_zoom),"Mouse-wheel zoom respects the overview limit")
	var magnify = InputEventMagnifyGesture.new()
	magnify.factor = 0.01
	world.handle_input(magnify)
	check(is_equal_approx(world.camera.size,world.overview_zoom),"Trackpad zoom respects the overview limit")
	check(not Grounds.walkable(Vector2(0,-19),0),"Locked garden land cannot be walked into")
	check(not Grounds.walkable(Vector2(0,-6),0),"Managers cannot walk through boarded wing entrances")
	var previous_edge: float = bounds.position.y
	for wing in range(1,4):
		app.model.hotels[0].wings = wing
		app._rebuild_world()
		check(is_equal_approx(world.navigation_bounds().position.y,previous_edge-2.5),"Restoring each wing opens the next garden strip")
		check(is_equal_approx(world.navigation_bounds().end.y,12.8),"Expanding never moves the front street boundary")
		check(shell.doors.size() == 5,"Restoring floor space retains the placed rooms' working doors")
		previous_edge = world.navigation_bounds().position.y
	check(app.model.grounds.perform(app.model,"walk",{"x":0,"z":-24}).ok,"Expanded garden land becomes playable after repairs")
	check(restored.restore(app.model.serialize()),"An in-progress garden walk can be saved and restored")
	app.model.advance(50)
	check(Vector2(app.model.grounds.hotels[0].manager[0],app.model.grounds.hotels[0].manager[1]).is_equal_approx(Vector2(0,-24)),"Manager routes reach unlocked garden paths")
	var job: Dictionary = Grounds.make_job("clean",0,Grounds.room_spot(1),Grounds.room_spot(0),4)
	check(Grounds.valid_job(job),"Room-to-room routes through both doors remain valid saved jobs")
	check(job.path.any(func(p): return Vector2(p[0],p[1]).is_equal_approx(Vector2(-1.6,0.65))) and job.path.any(func(p): return Vector2(p[0],p[1]).is_equal_approx(Vector2(-3.9,0.65))),"Housekeeping enters and leaves through the starter suite doors")
	var wing_route: Array = Grounds.route(Vector2(0,6),Grounds.room_spot(2))
	check(wing_route.has(Vector2(0,-5.75)),"Housekeeping uses the expanded room doorway")
	app._update_ui()
	world.set_motion_enabled(false)
	await capture("52-isometric-expanded")
	world.focus_zone(0)
	shell.open_door(0)
	shell._process(0.3)
	await capture("53-working-room-doors")
	world.reset_camera()
	app.ui.open_route("View", "Hotel")
	await click(app.ui.view_button)
	await capture("54-complete-hotel")
	app.ui.manager_mode_requested.emit(true)
	check(not world.exterior_view,"Controlling the manager reveals the interior")
	app.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	for suffix in [".0.json",".1.json",".0.json.tmp",".1.json.tmp"]:
		if FileAccess.file_exists(save_key+suffix): DirAccess.remove_absolute(save_key+suffix)
	print("VIEWS TESTS: ","PASS" if failures == 0 else "FAIL"," (",failures," failures)")
	quit(1 if failures else 0)
