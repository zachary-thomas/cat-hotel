extends Node3D
## Instance meshes share immutable resources. Pointer movement changes transforms only.
const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const Interior = preload("res://scripts/core/furniture_layout.gd")
const FOOTPRINT_HALO := 0.16
static var _prototypes: Dictionary = {}
var builder
var objects: Dictionary = {}
var entries: Array = []
var room_data: Dictionary = {}
var _ghost: Node3D
var _ghost_item: String = ""
var _marker: Node3D
var _selected: String = ""
var _marker_key: String = ""

func sync(room: Dictionary, instances: Array) -> void:
	top_level = true
	position = Vector3.ZERO
	room_data = room.duplicate(true)
	entries = instances.duplicate(true)
	var wanted: Dictionary = {}
	for instance in instances:
		var uid: String = instance.uid
		wanted[uid] = true
		if objects.has(uid) and objects[uid].get_meta("item","")!=instance.item:
			objects[uid].free()
			objects.erase(uid)
		if not objects.has(uid):
			var node: Node3D = _make_item(instance.item)
			node.name = "Furniture_"+uid.replace(":","_")
			node.set_meta("item",instance.item)
			node.set_meta("uid",uid)
			add_child(node)
			objects[uid] = node
		_place(objects[uid],room,instance)
	for uid in objects.keys():
		if not wanted.has(uid):
			objects[uid].free()
			objects.erase(uid)
	if _selected!="": select(_selected)

func _place(node: Node3D, room: Dictionary, instance: Dictionary) -> void:
	var size: Vector2i = Catalog.item(instance.item).footprint
	if int(instance.rotation)%2: size = Vector2i(size.y,size.x)
	node.position = Interior.local_to_world(room,Vector2(instance.x,instance.y)+Vector2(size)*0.5)
	node.rotation.y = -(int(room.rotation)+int(instance.rotation))*PI*0.5

func _make_item(id: String) -> Node3D:
	if not _prototypes.has(id): _prepare_prototype(id)
	var root_node = Node3D.new()
	var definition: Dictionary = Catalog.item(id)
	var prototype: Dictionary = _prototypes[id]
	var aabb: AABB = prototype.bounds
	var fit: Vector3 = Vector3((definition.footprint.x*0.55-0.08)/maxf(0.01,aabb.size.x),1.0,(definition.footprint.y*0.55-0.08)/maxf(0.01,aabb.size.z))
	var center: Vector3 = aabb.get_center()
	var transform := Transform3D(Basis.from_scale(fit),Vector3(-center.x*fit.x,0,-center.z*fit.z))
	for part in prototype.parts:
		var mesh = MultiMeshInstance3D.new()
		mesh.multimesh = part.mesh
		mesh.material_override = part.material
		mesh.transform = transform*part.transform
		root_node.add_child(mesh)
	root_node.set_meta("bounds",AABB(Vector3(-definition.footprint.x*0.55*0.5+0.04,aabb.position.y,-definition.footprint.y*0.55*0.5+0.04),Vector3(definition.footprint.x*0.55-0.08,aabb.size.y,definition.footprint.y*0.55-0.08)))
	return root_node

func _prepare_prototype(id: String) -> void:
	var node = Node3D.new()
	var definition: Dictionary = Catalog.item(id)
	if definition.provides_sleep:
		builder._bed(node,Vector3.ZERO,"cave" if id=="canopy_bed" else id,false)
		if id=="canopy_bed":
			for x in [-0.75,0.75]:
				for z in [-0.9,0.9]: builder._box(node,Vector3(x,1.2,z),Vector3(0.09,2.2,0.09),Color("a97758"))
			builder._box(node,Vector3(0,2.28,0),Vector3(1.65,0.14,2.0),Color("dbc5ad"))
			for x in [-0.78,0.78]: builder._box(node,Vector3(x,1.64,-0.68),Vector3(0.07,1.1,0.38),Color("f0dfcc"))
	elif id=="perch":
		# A raised window bench: warm timber frame, mint upholstery and a cozy pillow.
		builder._box(node,Vector3(0,0.07,0),Vector3(1.02,0.14,0.74),Color("a96f45"))
		for x in [-0.38,0.38]: builder._box(node,Vector3(x,0.43,0),Vector3(0.13,0.72,0.16),Color("c98957"))
		builder._box(node,Vector3(0,0.82,0),Vector3(1.12,0.16,0.80),Color("b97949"))
		builder._box(node,Vector3(0,0.96,-0.03),Vector3(1.02,0.18,0.68),Color("5cc8a1"))
		for x in [-0.45,0.45]: builder._box(node,Vector3(x,1.18,0.30),Vector3(0.11,0.58,0.12),Color("c98957"))
		builder._box(node,Vector3(0,1.46,0.30),Vector3(1.02,0.13,0.13),Color("c98957"))
		builder._box(node,Vector3(0.27,1.11,-0.08),Vector3(0.32,0.28,0.30),Color("f5a18f"))
	elif id in ["cloud_sofa","suite_sofa"]:
		# Face the approach edge at local north; this also fits the 3x2 footprint.
		builder._box(node,Vector3(0,0.25,0),Vector3(1.5,0.35,0.84),Color("9aafa0"))
		builder._box(node,Vector3(0,0.62,0.32),Vector3(1.5,0.55,0.20),Color("b0beaa"))
		for x in [-0.66,0.66]: builder._box(node,Vector3(x,0.48,0),Vector3(0.20,0.44,0.88),Color("8ca28d"))
		for x in [-0.30,0.30]:
			builder._box(node,Vector3(x,0.48,-0.08),Vector3(0.57,0.13,0.64),Color("d0d2b5") if id=="cloud_sofa" else Color("b1b99b"))
			builder._box(node,Vector3(x,0.66,0.08),Vector3(0.31,0.28,0.17),Color("e8bd91"))
	elif id=="room_nightstand": builder._nightstand(node,Vector3.ZERO,false)
	elif id=="suite_table": builder._table(node,Vector3.ZERO,Vector2(0.9,0.9),0.48,false)
	elif id=="adventure_tree":
		builder._item(node,"tower",Vector3.ZERO,false)
		builder._box(node,Vector3(-0.46,0.91,-0.31),Vector3(0.12,1.7,0.12),Color("bfa57a"))
		builder._box(node,Vector3(-0.46,1.82,-0.31),Vector3(0.75,0.14,0.75),Color("9caf7e"))
		builder._box(node,Vector3(-0.43,1.93,-0.31),Vector3(0.61,0.1,0.61),Color("e9d6a8"))
		builder._box(node,Vector3(0.43,0.51,0.35),Vector3(0.7,0.65,0.65),Color("bf9779"))
		builder._box(node,Vector3(0.43,0.48,0.685),Vector3(0.35,0.36,0.025),Color("6e6655"))
	else: builder._item(node,id,Vector3.ZERO,false)
	builder._flush(node)
	var parts: Array = []
	var bounds: AABB
	var first: bool = true
	for child in node.get_children():
		if not child is MultiMeshInstance3D: continue
		var child_bounds: AABB = child.transform*child.multimesh.get_aabb()
		bounds = child_bounds if first else bounds.merge(child_bounds)
		first = false
		parts.append({"mesh":child.multimesh,"material":child.material_override,"transform":child.transform})
	_prototypes[id] = {"parts":parts,"bounds":bounds}
	node.free()

func object_bounds(uid: String) -> AABB:
	return objects[uid].get_meta("bounds") if objects.has(uid) else AABB()

func show_ghost(room: Dictionary, instance: Dictionary, validation: Dictionary) -> void:
	if not is_instance_valid(_ghost) or _ghost_item!=instance.item:
		clear_ghost()
		_ghost_item = instance.item
		_ghost = _make_item(instance.item)
		_ghost.name = "FurnitureGhost"
		add_child(_ghost)
		for mesh in _ghost.get_children():
			var material = mesh.material_override.duplicate()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.no_depth_test = true
			material.render_priority = 2
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.set_meta("ghost_color",material.albedo_color)
			mesh.set_meta("ghost_vertex_color",material.vertex_color_use_as_albedo)
			mesh.set_meta("ghost_shading",material.shading_mode)
	_place(_ghost,room,instance)
	var valid: bool = bool(validation.get("ok",false))
	for mesh in _ghost.get_children():
		var material = mesh.material_override
		if valid:
			var original: Color = mesh.get_meta("ghost_color")
			material.albedo_color = Color(original.r,original.g,original.b,0.90)
			material.vertex_color_use_as_albedo = bool(mesh.get_meta("ghost_vertex_color"))
			material.shading_mode = int(mesh.get_meta("ghost_shading"))
		else:
			# MultiMesh vertex colors multiply the override material. Disable that
			# path so every invalid part reads as the same unmistakable red.
			material.albedo_color = Color(0.94,0.16,0.12,0.94)
			material.vertex_color_use_as_albedo = false
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_for(room,instance,valid)

func clear_ghost() -> void:
	if is_instance_valid(_ghost): _ghost.free()
	_ghost = null
	_ghost_item = ""
	clear_marker()

func clear_marker() -> void:
	if is_instance_valid(_marker): _marker.free()
	_marker = null
	_marker_key = ""

func select(uid: String) -> void:
	_selected = uid
	for instance in entries:
		if instance.uid==uid:
			_marker_for(room_data,instance,true)
			return
	clear_marker()

func _marker_for(room: Dictionary, instance: Dictionary, valid: bool) -> void:
	var key: String = str(room)+str(instance)+str(valid)
	if key==_marker_key: return
	clear_marker()
	_marker_key = key
	_marker = Node3D.new()
	_marker.name = "FurnitureFootprint"
	add_child(_marker)
	var color: Color = Color("42d487") if valid else Color("ed5145")
	var size: Vector2i = Catalog.item(instance.item).footprint
	var unit: float = Interior.CELL_SIZE
	_place(_marker,room,instance)
	var fill_mesh := PlaneMesh.new()
	# A small visual halo keeps the green/red pad readable around broad bases.
	# Logical occupancy and the inner border still use the exact grid footprint.
	fill_mesh.size = Vector2(size.x*unit,size.y*unit)+Vector2.ONE*FOOTPRINT_HALO
	var fill := MeshInstance3D.new()
	fill.name = "FurnitureFootprintFill"
	fill.mesh = fill_mesh
	fill.position.y = 0.045
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fill_material := StandardMaterial3D.new()
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.no_depth_test = true
	fill_material.render_priority = 1
	fill_material.albedo_color = Color(color.r,color.g,color.b,0.76 if valid else 0.80)
	fill.material_override = fill_material
	_marker.add_child(fill)
	var border_color := color.lightened(0.08)
	for x in [-size.x*unit*0.5,size.x*unit*0.5]: builder._box(_marker,Vector3(x,0.058,0),Vector3(0.055,0.032,size.y*unit+0.055),border_color,false,true)
	for z in [-size.y*unit*0.5,size.y*unit*0.5]: builder._box(_marker,Vector3(0,0.058,z),Vector3(size.x*unit+0.055,0.032,0.055),border_color,false,true)
	builder._flush(_marker)
	# RoomBuilder batches use shared cached materials. Give preview borders their
	# own overlay materials so foreground walls cannot hide them and committed
	# geometry keeps its original depth behavior.
	for child in _marker.get_children():
		if child == fill or not child is GeometryInstance3D or child.material_override == null: continue
		var border_material = child.material_override.duplicate()
		border_material.no_depth_test = true
		border_material.render_priority = 1
		child.material_override = border_material

func pick(camera: Camera3D, screen: Vector2) -> Array[String]:
	var hits: Array = []
	for uid in objects:
		var node: Node3D = objects[uid]
		var box: AABB = node.get_meta("bounds")
		var rect := Rect2(camera.unproject_position(node.to_global(box.position)),Vector2.ZERO)
		for index in range(8): rect = rect.expand(camera.unproject_position(node.to_global(box.get_endpoint(index))))
		if rect.grow(5).has_point(screen): hits.append({"uid":uid,"distance":camera.global_position.distance_squared_to(node.global_position)})
	hits.sort_custom(func(a,b): return a.distance<b.distance)
	var result: Array[String] = []
	for hit in hits: result.append(hit.uid)
	return result

static func use_anchor(room: Dictionary, instance: Dictionary) -> Vector3:
	var definition: Dictionary = Catalog.item(instance.item)
	var target: Vector3 = definition.animation_target
	var point: Vector2 = Vector2(instance.x,instance.y)+Interior._rotated_point(Vector2(target.x,target.z),definition.footprint,int(instance.rotation))
	return Interior.local_to_world(room,point)+Vector3(0,target.y,0)
