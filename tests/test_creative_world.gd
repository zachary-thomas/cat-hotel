extends SceneTree
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not FileAccess.file_exists("res://scripts/creative/creative_world.gd"):
		check(false,"Creative hotel needs dynamic room shells and unobstructed framing")
		quit(1)
		return
	var model_script = load("res://scripts/creative/creative_model.gd")
	var world_script = load("res://scripts/creative/creative_world.gd")
	var model = model_script.new()
	model.new_game(1000)
	var world = world_script.new()
	if OS.has_environment("CREATIVE_CAPTURE"):
		root.size = Vector2i(1280,800)
		root.content_scale_size = Vector2i(1280,800)
	root.add_child(world)
	world.setup(model)
	await process_frame
	world.set_world_rect(Rect2(25,70,900,580))
	world.focus_hotel()
	await process_frame
	check(world.room_nodes.size()==model.hotel().rooms.size(),"Every dynamic room has its own rendered shell")
	check(world.object_nodes.size()==model.hotel().objects.size(),"Every editable item has one scene object")
	var neighbor=world.neighborhood.pedestrians[0].node
	var saved_state:Dictionary=model.serialize()
	world.neighborhood.advance(10.0)
	check(model.serialize()==saved_state,"Neighborhood activity never awards income or changes a save")
	var neighbor_position:Vector3=neighbor.position
	model._invalidate(); world.sync()
	check(world.neighborhood.pedestrians[0].node==neighbor and neighbor.position==neighbor_position,"Building revisions preserve neighborhood pedestrians and their positions")
	model.state.settings.motion=false
	world.apply_visual_settings()
	world.neighborhood.advance(10.0)
	check(neighbor.position==neighbor_position,"Motion setting immediately freezes sidewalk cats")
	var water_checked: bool = false
	for mesh in world.find_children("*","MeshInstance3D",true,false):
		var material = mesh.material_override
		if material is ShaderMaterial and material.shader.resource_path.ends_with("water.gdshader"):
			water_checked=true
			check(is_zero_approx(float(material.get_shader_parameter("motion"))),"Motion setting stops water immediately without a geometry revision")
	check(water_checked,"World motion test includes real water geometry")
	model.state.settings.motion=true
	world.apply_visual_settings()
	world.set_outside(true)
	for node in world.room_nodes.values():
		if node.has_node("Roof"): check(node.get_node("Roof").visible,"Exterior displays complete automatic roofs")
	world.set_outside(false)
	for node in world.room_nodes.values():
		if node.has_node("Roof"): check(not node.get_node("Roof").visible,"Cutaway hides roofs for direct editing")
	var screen: Vector2 = world.camera.unproject_position(Vector3(3.3,0.18,4.4))
	check(world.world_point(screen).distance_to(Vector2(3,4))<0.03,"Pointer picking uses the same lot coordinate system as construction")
	var before: Vector2 = world.world_point(Rect2(25,70,900,580).get_center())
	world.set_world_rect(Rect2(330,70,595,580))
	await process_frame
	var after: Vector2 = world.world_point(Rect2(330,70,595,580).get_center())
	check(before.distance_to(after)<0.1,"Opening a tray preserves the visible world's camera focus")
	world.set_preview("place_room",{"kind":"cottage","x":0,"y":0,"w":6,"h":4,"rotation":1},false)
	check(world.get_node("Preview").get_child_count()>0,"An invalid placement remains reviewable as a footprint")
	world.clear_preview()
	check(world.get_node("Preview").get_child_count()==0,"Clearing a preview removes its geometry")
	if OS.has_environment("CREATIVE_CAPTURE"):
		world.set_world_rect(Rect2(0,0,1280,800))
		for index in range(4):
			model.state.current_hotel=index
			model.revision += 1
			model.advance(20)
			world.sync()
			world.focus_lot()
			for _frame in range(5): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/creative-world-%d.png" % index)
		world.set_outside(true)
		world.focus_hotel()
		for _frame in range(5): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/creative-world-exterior.png")
		model.state.current_hotel=1
		model.revision += 1
		for _step in range(1200):
			model.advance(0.25)
			var seated: bool = false
			for actor in model.social.agents.values():
				if actor.phase=="sit" and actor.drink: seated=true
			if seated: break
		world.sync()
		world.set_outside(false)
		var geometry = load("res://scripts/creative/lot_geometry.gd")
		for room in model.hotel().rooms:
			if room.kind=="terrace": world.focus_bounds(geometry.room_rect(room).grow(1.5))
		for _frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/creative-world-cafe-close.png")
	world.free()
	print("CREATIVE WORLD: %d failures" % failures)
	quit(1 if failures else 0)
