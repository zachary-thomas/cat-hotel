extends SceneTree
const Model = preload("res://scripts/core/hotel_model.gd")
var failures := 0
var app
class BrokenStore:
	extends RefCounted
	var error_message := "Simulated storage failure"
	func save_model(_model) -> bool: return false

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(file: String) -> void:
	app.ui.toast_timer=0; app.ui.toast_label.hide()
	for frame in range(4): await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/"+file+"-"+str(DisplayServer.window_get_size().x)+".png")

func tap(control: Control) -> void:
	await process_frame
	var position: Vector2=control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=position; event.pressed=pressed
		root.push_input(event,true); await process_frame

func run() -> void:
	var model = Model.new()
	model.new_game(1000)
	model.coins = 10000
	check(model.grounds.perform(model,"amenity",{"id":"pool"}).ok,"Buy a pool before rearranging it")
	var before: float = model.coins
	check(model.grounds.perform(model,"move_amenity",{"id":"pool","x":15.0,"z":-7.0,"rotation":1}).ok,"An owned pool can move into the larger starting garden")
	check(model.coins == before,"Moving an amenity is free")
	check(not model.grounds.perform(model,"move_amenity",{"id":"pool","x":0.0,"z":0.0}).ok,"Amenity placement keeps hotel floors clear")
	check(not model.grounds.perform(model,"move_amenity",{"id":"pool","x":24.0,"z":-7.0}).ok,"Unopened plots reject placement")
	check(model.grounds.perform(model,"expand_plot",{"id":"east"}).ok,"Players may expand east first")
	check(model.grounds.perform(model,"move_amenity",{"id":"pool","x":24.0,"z":-7.0,"rotation":3}).ok,"Purchased land accepts a moved pool")
	var restored = Model.new()
	check(restored.restore(model.serialize()),"Land and amenity positions survive a save round trip")
	check(not model.grounds.perform(model,"expand_plot",{"id":"east"}).ok,"A plot cannot be bought twice")
	check(restored.grounds.hotels[0].plots==["east"] and restored.grounds.hotels[0].amenity_layout.pool=={"x":24.0,"z":-7.0,"rotation":3},"Reload restores the chosen plot, position and orientation exactly")
	for payload in [{"id":"pool","x":INF,"z":0},{"id":"pool","x":15,"z":-7,"rotation":1.5},{"id":"litter","x":15,"z":-7},{"id":"pool","x":-9.1,"z":1.8},{"id":"pool","x":15,"z":12}]:
		check(not model.grounds.perform(model,"move_amenity",payload).ok,"Invalid, overlapping, unowned and street placements are rejected")
	var old: Dictionary=model.serialize()
	for data in old.grounds.hotels: data.erase("plots"); data.erase("amenity_layout")
	check(restored.restore(old) and restored.grounds.hotels[0].plots.is_empty() and restored.grounds.hotels[0].amenity_layout.is_empty(),"Existing saves migrate with their original amenity sites")
	for bad in [["east","east"],["ocean"]]:
		var corrupt: Dictionary=model.serialize(); corrupt.grounds.hotels[0].plots=bad
		check(not restored.restore(corrupt),"Malformed land ownership is rejected")
	var corrupt: Dictionary=model.serialize(); corrupt.grounds.hotels[0].amenity_layout.pool.x=0
	check(not restored.restore(corrupt),"Saved amenities cannot overlap the building")
	check(model.grounds.perform(model,"walk",{"x":27,"z":-10}).ok,"The manager can walk into purchased land")
	var job: Dictionary=model.grounds.hotels[0].job
	var obstacle: Rect2=model.grounds.Garden.footprint(Vector2(24,-7),3).grow(0.39)
	for i in range(1,job.path.size()):
		var a := Vector2(job.path[i-1][0],job.path[i-1][1]); var b := Vector2(job.path[i][0],job.path[i][1])
		check(not model.grounds._segment_intersects_rect(a,b,obstacle),"The walking route goes around the moved pool")
	check(restored.restore(model.serialize()),"Long outdoor routes survive reopening")
	model.grounds.advance(job.duration+0.1,model)
	check(Vector2(model.grounds.hotels[0].manager[0],model.grounds.hotels[0].manager[1]).is_equal_approx(Vector2(27,-10)),"The manager reaches the new garden")
	DirAccess.make_dir_recursive_absolute("res://tmp")
	app=load("res://scenes/main.tscn").instantiate()
	app.save_path="res://tmp/neighborhood-"+str(Time.get_ticks_usec())
	root.add_child(app); await process_frame; app.start_game()
	app.model.coins=10000; app.model.hotels[0].purchases=20
	for id in ["pool","litter","picnic","playpen"]: app.perform_grounds("amenity",{"id":id})
	app.model.settings.motion=false; app.model.settings.weather=false
	app.world.apply_life(app.model); app.world.set_motion_enabled(false)
	app.ui.close_sheet(); app.world.reset_camera()
	await capture("neighborhood-expanded")
	var pool = app.world.neighborhood.details.get_node("Pool")
	check(pool.get_node("PoolWater").material_override is ShaderMaterial,"The kitty pool uses the ripple water material")
	check(pool.get_node("PoolWater").position.y < pool.get_node("PoolRim").position.y,"Pool water sits inside the rim")
	app.ui.open_amenity("pool")
	var button: Button=app.ui.sheet.find_child("MoveOwnedAmenity",true,false)
	check(button!=null,"Owned amenity details expose Move")
	app.ui.garden_edit_requested.emit("pool")
	await process_frame
	var editor=app.garden_editor
	check(editor.visible and editor.selected_id=="pool" and not pool.visible,"The editor replaces the old object with its preview")
	editor.move_to(Vector2(0,0))
	check(editor.confirm_button.disabled,"Invalid placement disables Move")
	editor.move_to(Vector2(15,-7)); editor.rotate()
	var pool_center := Vector3(15,0,-7)
	app.world._center_projected(Rect2(Vector2(pool_center.dot(app.world.ISO_RIGHT),pool_center.dot(app.world.ISO_UP)),Vector2.ZERO))
	await capture("garden-amenity-preview")
	await tap(editor.confirm_button)
	check(app.model.grounds.hotels[0].amenity_layout.has("pool"),"The real Move button saves the placement")
	check(app.world.neighborhood.details.get_node("Pool").position.is_equal_approx(Vector3(15,0.12,-7)),"The amenity and its cat move to the saved location")
	editor.select_amenity("pool"); editor.move_to(Vector2(15,-15)); editor.cancel()
	check(app.model.grounds.hotels[0].amenity_layout.pool.z==-7,"Cancel preserves the last saved position")
	editor.select_amenity("pool"); editor.move_to(Vector2(15,-15))
	var original_store=app.store; app.store=BrokenStore.new()
	editor.confirm()
	check(app.model.grounds.hotels[0].amenity_layout.pool.z==-7 and editor.selected_id=="pool","Failed saving restores the old location and keeps the preview retryable")
	app.store=original_store; app.save_error=""; editor.cancel(); editor.close()
	var garden_before: Dictionary=app.model.grounds.hotels[0].duplicate(true)
	var coins_before: float=app.model.coins
	app.store=BrokenStore.new(); app.perform_grounds("expand_plot",{"id":"west"})
	check(app.model.grounds.hotels[0].plots==garden_before.plots and is_equal_approx(app.model.coins,coins_before),"Failed land purchases restore coins and land ownership")
	app.store=original_store; app.save_error=""
	app.perform_grounds("expand_plot",{"id":"east"})
	app.world.camera_target=Vector3(18,0,-12); app.world.set_zoom(65)
	await capture("neighborhood-east-garden")
	app.model.hotels[1].owned=true; app.model.current_hotel=1; app.model.furniture.ensure_rooms(app.model,1); app._rebuild_world(); app._update_ui()
	app.world.camera_target=Vector3(4,0,12); app.world.set_zoom(55)
	await capture("seaside-coast")
	var water = app.world.building.get_node("SeasideWater")
	check(water.mesh.size.x>=500 and water.mesh.size.y>=250,"The sea extends beyond every allowed camera position")
	app.world.set_zoom(1e6)
	for direction in [Vector2(1e6,0),Vector2(-1e6,0),Vector2(0,1e6),Vector2(0,-1e6)]:
		app.world._pan(direction); var stopped: Vector3=app.world.camera_target; app.world._pan(direction)
		check(app.world.camera_target.is_equal_approx(stopped),"Repeated dragging stops at each neighborhood boundary")
		var viewport: Rect2=root.get_visible_rect()
		for screen in [viewport.position,viewport.end,Vector2(viewport.end.x,viewport.position.y),Vector2(viewport.position.x,viewport.end.y)]:
			var p: Vector3=Plane(Vector3.UP,-0.34).intersects_ray(app.world.camera.project_ray_origin(screen),app.world.camera.project_ray_normal(screen))
			check(absf(p.x)<255 and p.z>-249 and p.z<270,"Scenic terrain covers every viewport corner at maximum zoom and the pan limits")
	await capture("seaside-map-boundary")
	app.change_setting("ui_text_scale",1.5)
	app.perform_grounds("amenity",{"id":"pool"}); app.garden_editor.open("pool")
	await capture("garden-large-text")
	check(app.garden_editor.confirm_button.get_global_rect().end.y<=root.get_visible_rect().end.y,"Move stays accessible with large text")
	app.garden_editor.close()
	for hotel in [2,3]:
		app.model.hotels[hotel].owned=true; app.model.current_hotel=hotel; app.model.furniture.ensure_rooms(app.model,hotel); app._rebuild_world(); app._update_ui(); app.world.reset_camera()
		check(app.world.navigation_bounds().size.x>70,"Every destination has a neighborhood to explore")
		await capture("expanded-hotel-"+str(hotel))
	app.active=false; app.soundscape.shutdown(); await create_timer(0.2).timeout; app.queue_free(); await process_frame
	print("NEIGHBORHOOD EXPANSION: ",failures," failures")
	quit(1 if failures else 0)
