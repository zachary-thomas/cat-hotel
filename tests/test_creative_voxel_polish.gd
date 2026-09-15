extends SceneTree
var failures: int = 0
const Model = preload("res://scripts/creative/creative_model.gd")
const World = preload("res://scripts/creative/creative_world.gd")
const Objects = preload("res://scripts/creative/creative_objects.gd")
const Content = preload("res://scripts/creative/creative_content.gd")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model = Model.new()
	model.new_game(1000)
	var world = World.new()
	root.size = Vector2i(1280,800)
	root.content_scale_size = Vector2i(1280,800)
	root.add_child(world)
	world.setup(model)
	world.set_world_rect(Rect2(0,0,1280,800))
	world.focus_hotel()
	await process_frame
	check(world.get_node("Grounds").has_node("VillageRoad"),"Meadow renders the street supplied by its map")
	var fountain: Node3D = Objects.make(Content.item("fountain"))
	root.add_child(fountain)
	var drops: MultiMeshInstance3D = fountain.get_node("VoxelSpillways")
	check(drops.multimesh.instance_count==56,"All eight fountain spillways use real cube droplets in one batch")
	drops.set_motion_enabled(false)
	var first_transform: Transform3D = drops.multimesh.get_instance_transform(0)
	drops._process(0.4)
	check(first_transform==drops.multimesh.get_instance_transform(0),"Reduced motion freezes fountain droplets")
	drops.set_motion_enabled(true)
	drops._process(0.4)
	check(drops._elapsed>0.0,"Fountain animation advances while motion is enabled")
	if DisplayServer.get_name()!="headless": check(first_transform!=drops.multimesh.get_instance_transform(0),"Native rendered water cubes change position")
	for mesh in fountain.find_children("*","MeshInstance3D",true,false):
		check(mesh.mesh is BoxMesh,"Fountain water is a voxel volume")
	fountain.free()
	# A single furniture reservation can expose several social approach slots.
	# Its visual occupancy must still respect the real available seat width.
	var saved_agents: Dictionary = model.social.agents.duplicate(true)
	for item_id in ["cloud_sofa","lounge_sofa","picnic","perch","mat"]:
		var furniture: Node3D = Objects.make(Content.item(item_id))
		world.add_child(furniture)
		world.object_nodes["pose_test"] = furniture
		model.social.agents.clear()
		for index in range(4):
			model.social.agents[index] = {"cat":index,"phase":"activity","venue":"pose_test","slot":str(index)}
		var positions: Array[Vector3] = []
		for data in model.social.agents.values():
			var pose: Dictionary = world._furniture_pose(data)
			if pose.is_empty(): continue
			for other in positions: check(Vector3(pose.position).distance_to(other)>=0.78,"Occupied "+item_id+" poses fit distinct cat bodies")
			positions.append(pose.position)
		check(not positions.is_empty(),"Usable furniture has a physical resting pose")
		furniture.free()
		world.object_nodes.erase("pose_test")
	model.social.agents = saved_agents
	var separation: float = INF
	for step in range(600):
		model.advance(0.1)
		world._sync_actors(1.0)
		var ids: Array = world.actors.keys()
		for i in range(ids.size()):
			for j in range(i+1,ids.size()):
				var a: Vector3 = world.actors[ids[i]].position
				var b: Vector3 = world.actors[ids[j]].position
				if absf(a.y-b.y)>0.55: continue
				separation = minf(separation,Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z)))
	check(separation>=0.77,"Rendered cat bodies remain distinct through a minute of travel and furniture activity")
	if OS.has_environment("VOXEL_CAPTURE"):
		for step in range(160): model.advance(0.1)
		for frame in range(12): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/voxel-meadow-overview.png")
		world.focus_bounds(Rect2(-10.4,-10.4,13.0,13.2))
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/voxel-hotel-close.png")
		world.focus_bounds(Rect2(4,-6,6,7))
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/voxel-garden-close.png")
	# Readability remains enforced even when the room is unfinished in exterior.
	var room_id: String = String(model.hotel().rooms[0].id)
	var keep: Array = []
	for item in model.hotel().objects:
		if String(item.get("room",""))!=room_id: keep.append(item)
	model.hotel().objects = keep
	model._invalidate()
	world.sync()
	world.set_outside(true)
	world.focus_hotel()
	var title: Node3D = world.room_nodes[room_id].get_node("RoomName")
	check(title.has_node("Status"),"Unfinished rooms have an explicit status label")
	if title.has_node("Status"):
		var warning: Node3D = title.get_node("Status")
		world._update_status_badges()
		var badge: Dictionary = world._status_badges[room_id]
		check(warning.position.y>=4.5 and badge.panel.visible and badge.label.get_theme_font_size("font_size")>=15,"Room warnings use readable screen-space badges above roofs")
	if OS.has_environment("VOXEL_CAPTURE"):
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/voxel-room-warning.png")
		root.size = Vector2i(390,844)
		root.content_scale_size = root.size
		world.set_world_rect(Rect2(12,95,366,520))
		world.focus_hotel()
		model.state.settings.ui_text_scale = 1.5
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/voxel-room-warning-phone.png")
	model.hotel().objects.append({"id":"old_model_only","item":"flowers","room":"","x":8,"y":8,"rotation":0,"paid":0})
	model._invalidate()
	world.sync()
	check(world.object_nodes.has("old_model_only"),"Reset regression begins with distinct old furniture")
	var replacement = Model.new()
	replacement.new_game(1000)
	replacement.revision = model.revision
	world.setup(replacement)
	check(not world.object_nodes.has("old_model_only"),"Replacing a model clears old geometry even when revisions match")
	check(world.object_nodes.size()==replacement.hotel().objects.size(),"Replacing a model renders every fresh item")
	world.free()
	print("CREATIVE VOXEL POLISH: %d failures" % failures)
	quit(1 if failures else 0)
