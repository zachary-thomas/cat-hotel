extends SceneTree

const Renderer = preload("res://scripts/world/furniture_renderer.gd")
const Builder = preload("res://scripts/world/room_builder.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func room() -> Dictionary:
	return {"kind":"regular","x":0,"y":9,"rotation":0}

func item(uid: String, x: int = 3, y: int = 3, rotation: int = 0) -> Dictionary:
	return {"uid":uid,"item":"scratch","hotel":0,"room":0,"x":x,"y":y,"rotation":rotation}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var builder = Builder.new()
	root.add_child(builder)
	var renderer = Renderer.new()
	renderer.builder = builder
	root.add_child(renderer)
	var perch = renderer._make_item("perch")
	var has_mint_cushion := false
	var has_coral_pillow := false
	for mesh in perch.get_children():
		var color: Color=mesh.material_override.albedo_color
		if color.g>0.65 and color.r<0.50 and color.b>0.45: has_mint_cushion=true
		if color.r>0.85 and color.g>0.45 and color.g<0.75: has_coral_pillow=true
	check(has_mint_cushion,"Window perch has a recognizable mint upholstered seat in live geometry")
	check(has_coral_pillow and perch.get_child_count()>=5,"Window perch has a distinct cozy pillow and timber bench structure")
	perch.free()
	renderer.sync(room(),[item("f1",1,1)])
	var committed = renderer.objects.f1
	var committed_color: Color = committed.get_child(0).material_override.albedo_color
	renderer.sync(room(),[item("f1",2,1)])
	check(renderer.objects.f1 == committed,"Moving a committed UID keeps its render node")
	renderer.show_ghost(room(),item("draft:test:1"),{"ok":true})
	var ghost = renderer._ghost
	var ghost_id: int = ghost.get_instance_id()
	var valid_colors: Array[Color] = []
	for mesh in ghost.get_children():
		valid_colors.append(mesh.material_override.albedo_color)
		check(mesh.material_override.albedo_color.a >= 0.85,"Valid ghost is strongly visible")
		check(mesh.material_override.no_depth_test and mesh.material_override.render_priority == 2,"Ghost renders through foreground room geometry")
	var fill = renderer._marker.get_node_or_null("FurnitureFootprintFill")
	check(fill != null and fill.mesh is PlaneMesh and fill.mesh.size.is_equal_approx(Vector2(0.55,1.10)+Vector2.ONE*Renderer.FOOTPRINT_HALO),"Filled feedback covers the complete footprint with a visible rim around wide furniture bases")
	check(fill.material_override.albedo_color.g > fill.material_override.albedo_color.r,"Valid footprint fill is green beneath the original-color object")
	check(fill.material_override.no_depth_test and fill.material_override.render_priority == 1,"Filled footprint renders through the floor below the ghost")
	for border in renderer._marker.get_children():
		if border == fill or not border is GeometryInstance3D: continue
		check(border.material_override.no_depth_test and border.material_override.render_priority == 1,"Footprint border renders through foreground room geometry")
	renderer.show_ghost(room(),item("draft:test:1",4,3),{"ok":false})
	check(renderer._ghost.get_instance_id() == ghost_id,"Pointer movement and validity changes reuse ghost geometry")
	for mesh in renderer._ghost.get_children():
		var red: Color = mesh.material_override.albedo_color
		check(red.r > 0.9 and red.g < 0.2 and red.b < 0.2 and red.a > 0.9,"Every invalid ghost part is strongly opaque red")
		check(not mesh.material_override.vertex_color_use_as_albedo and mesh.material_override.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,"Invalid red cannot be tinted by MultiMesh colors or lighting")
	check(renderer._marker.get_node("FurnitureFootprintFill").material_override.albedo_color.r > 0.8,"Invalid footprint fill is red")
	renderer.show_ghost(room(),item("draft:test:1",4,3),{"ok":true})
	for index in range(renderer._ghost.get_child_count()):
		var restored: Color = renderer._ghost.get_child(index).material_override.albedo_color
		check(restored.is_equal_approx(Color(valid_colors[index].r,valid_colors[index].g,valid_colors[index].b,0.90)),"Valid state restores each original part color")
	check(committed.get_child(0).material_override.albedo_color == committed_color,"Ghost material changes never alter committed geometry or cached prototypes")
	check(not committed.get_child(0).material_override.no_depth_test,"Committed furniture retains normal depth testing")
	renderer.show_ghost(room(),item("draft:test:1",4,3,1),{"ok":true})
	fill = renderer._marker.get_node("FurnitureFootprintFill")
	var world_bounds: AABB = fill.global_transform * fill.mesh.get_aabb()
	check(world_bounds.size.x > world_bounds.size.z and is_equal_approx(world_bounds.size.x,1.10+Renderer.FOOTPRINT_HALO) and is_equal_approx(world_bounds.size.z,0.55+Renderer.FOOTPRINT_HALO),"Rotated footprint fill swaps its world width and depth")
	renderer.clear_ghost()
	check(not is_instance_valid(renderer._ghost) and not is_instance_valid(renderer._marker),"Cancel clears ghost and footprint feedback")
	renderer.free()
	builder.free()
	print("FURNITURE PREVIEW TESTS: ","PASS" if failures == 0 else "FAIL"," (",failures," failures)")
	quit(1 if failures else 0)
