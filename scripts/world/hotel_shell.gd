extends Node3D
## Doors stay interactive in the cutaway; the full shell is a reversible view layer.
var world
var exterior: Node3D
var doors_root: Node3D
var border: Node3D
var doors: Array = []
var materials: Dictionary = {}
var outside: bool = false

func block(parent: Node3D, p: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var item = MeshInstance3D.new()
	item.mesh = BoxMesh.new()
	item.position = p
	item.scale = dimensions
	var key: String = color.to_html()
	if not materials.has(key):
		var material = ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/voxel_surface.gdshader")
		material.set_shader_parameter("tint",color)
		materials[key] = material
	item.material_override = materials[key]
	parent.add_child(item)
	return item

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	doors.clear()
	exterior = Node3D.new()
	exterior.name = "FullHotelExterior"
	add_child(exterior)
	doors_root = Node3D.new()
	doors_root.name = "WorkingRoomDoors"
	add_child(doors_root)
	border = Node3D.new()
	border.name = "GrowingGardenBoundary"
	add_child(border)
	if world.room_builder != null and world.room_builder.model != null:
		var layout: Array = world.Layout.entries(world.room_builder.model,world.hotel_index)
		for room in range(layout.size()):
			var yaw: float = PI/2 if int(layout[room].rotation)%2==0 else 0.0
			make_door(world.room_builder.door_position(room),yaw,0.82,"Room %d" % (room+1),false,room)
	make_door(Vector3(-0.53,0.12,4.78),0,1.05,"Front entrance",true,-1)
	make_door(Vector3(0.53,0.12,4.78),PI,1.05,"Front entrance",true,-1)
	make_door(Vector3(0,0.24,-17.22),0,1.35,"Garden door",true,-1)
	_build_exterior()
	_build_boundary()
	_batch_static(exterior)
	_batch_static(border)
	set_outside(outside)

func _batch_static(root: Node3D) -> void:
	# Roof tiles and garden trim share a handful of draw calls. Door leaves stay
	# separate so their hinges can move independently.
	var groups: Dictionary = {}
	for item in root.find_children("*","MeshInstance3D",true,false):
		var material = item.material_override
		var key: int = material.get_instance_id()
		if not groups.has(key):
			groups[key] = {"material":material,"transforms":[]}
		groups[key].transforms.append(root.global_transform.affine_inverse()*item.global_transform)
		item.get_parent().remove_child(item)
		item.queue_free()
	for group in groups.values():
		var batch = MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = BoxMesh.new()
		batch.instance_count = group.transforms.size()
		for i in range(batch.instance_count):
			batch.set_instance_transform(i,group.transforms[i])
		var instance = MultiMeshInstance3D.new()
		instance.multimesh = batch
		instance.material_override = group.material
		root.add_child(instance)

func make_door(center: Vector3, yaw: float, width: float, title: String, entrance: bool, room: int) -> void:
	var frame = Node3D.new()
	doors_root.add_child(frame)
	frame.name = title.replace(" ","")
	frame.position = center
	frame.rotation.y = yaw
	var height: float = 2.2 if entrance else 1.75
	for side in [-1,1]:
		block(frame,Vector3(side*(width/2+0.055),height/2,0),Vector3(0.11,height+0.1,0.18),world.wood.darkened(0.15))
	block(frame,Vector3(0,height+0.06,0),Vector3(width+0.2,0.13,0.18),world.wood)
	var pivot = Node3D.new()
	frame.add_child(pivot)
	pivot.position.x = -width/2
	block(pivot,Vector3(width/2,height/2,0),Vector3(width-0.035,height,0.11),world.trim if entrance else world.accent)
	block(pivot,Vector3(width/2,height*0.70,0.075),Vector3(width*0.70,height*0.32,0.055),Color("c6ded3") if entrance else world.accent.lightened(0.2))
	block(pivot,Vector3(width/2,height*0.25,0.075),Vector3(width*0.70,height*0.25,0.045),world.trim.lightened(0.12))
	block(pivot,Vector3(width-0.16,height*0.46,0.11),Vector3(0.08,0.07,0.07),Color("e7c267"))
	doors.append({"frame":frame,"pivot":pivot,"position":center,"hold":0.0,"open":false,"entrance":entrance,"room":room})

func set_outside(value: bool) -> void:
	outside = value
	if exterior != null:
		exterior.visible = value
	for door in doors:
		door.frame.visible = door.entrance or not value

func open_door(index: int) -> void:
	if index >= 0 and index < doors.size():
		doors[index].hold = 4.0
		doors[index].open = true

func select_door(screen_pos: Vector2) -> bool:
	var nearest: int = -1
	var distance: float = 16.0 if world.camera.size < 25 else 10.0
	for i in range(doors.size()):
		var door: Dictionary = doors[i]
		if not door.frame.visible or (outside and door.position.z < 4.0):
			continue
		var p: Vector2 = world.camera.unproject_position(door.position+Vector3(0,0.8,0))
		var d: float = p.distance_to(screen_pos)
		if d < distance:
			distance = d
			nearest = i
	if nearest >= 0:
		open_door(nearest)
		return true
	return false

func roof_hit(screen_pos: Vector2) -> bool:
	return outside and AABB(Vector3(-5.95,0,-17.4),Vector3(11.9,5.8,22.3)).intersects_ray(world.camera.project_ray_origin(screen_pos),world.camera.project_ray_normal(screen_pos)) != null

func _build_exterior() -> void:
	var cream = Color("e8dcc0")
	var back: float = -17.3
	var front: float = 4.83
	for side in [-1,1]:
		block(exterior,Vector3(side*5.78,1.72,(back+front)/2),Vector3(0.24,3.22,front-back),cream)
		block(exterior,Vector3(side*5.92,0.6,(back+front)/2),Vector3(0.08,0.65,front-back),world.wood)
		block(exterior,Vector3(side*5.94,3.08,(back+front)/2),Vector3(0.10,0.16,front-back+0.1),world.trim)
		for z in [-14.8,-10.6,-6.4,-2.7,1.4]:
			var window = Node3D.new()
			exterior.add_child(window)
			window.position = Vector3(side*5.94,1.92,z)
			window.rotation.y = side*PI/2
			window_detail(window)
		block(exterior,Vector3(side*3.53,1.72,front),Vector3(4.55,3.22,0.24),cream)
		block(exterior,Vector3(side*3.35,1.72,back),Vector3(5.0,3.22,0.24),cream)
		var window = Node3D.new()
		exterior.add_child(window)
		window.position = Vector3(side*3.7,1.9,front+0.14)
		window_detail(window)
	block(exterior,Vector3(0,2.9,front),Vector3(2.35,0.8,0.24),cream)
	block(exterior,Vector3(0,3.0,back),Vector3(1.6,0.6,0.24),cream)
	# A stepped pitched roof retains the voxel style, with tiled rows and dormers.
	var roof_color: Color = [Color("648a82"),Color("698ea4"),Color("a47862"),Color("8393b6")][world.hotel_index]
	for side in [-1,1]:
		for step in range(13):
			var x: float = side*(0.25+step*0.49)
			var y: float = 5.5-step*0.17
			block(exterior,Vector3(x,y,(back+front)/2),Vector3(0.55,0.22,23.0),roof_color.lightened(0.018*(step%3)))
			for row in range(23):
				block(exterior,Vector3(x,y+0.12,back-0.35+row),Vector3(0.51,0.04,0.05),roof_color.darkened(0.14))
	block(exterior,Vector3(0,5.62,(back+front)/2),Vector3(0.40,0.20,23.15),world.trim)
	for z in [-12.8,-6.1,0.5]:
		block(exterior,Vector3(3.3,4.6,z),Vector3(1.65,1.2,1.5),cream)
		block(exterior,Vector3(3.3,5.22,z),Vector3(1.9,0.19,1.8),world.trim)
		var window = Node3D.new()
		exterior.add_child(window)
		window.position = Vector3(4.15,4.65,z)
		window.rotation.y = PI/2
		window.scale = Vector3.ONE*0.8
		window_detail(window)
	# Fill the front and rear roof triangles so this is a complete building.
	for step in range(11):
		var y: float = 3.3+step*0.2
		var width: float = maxf(0.5,11.65-step*1.03)
		for z in [front,back]:
			block(exterior,Vector3(0,y,z),Vector3(width,0.22,0.18),cream)
	block(exterior,Vector3(-2.0,5.3,-9.0),Vector3(0.7,1.6,0.75),Color("ae8976"))
	block(exterior,Vector3(-2.0,6.13,-9.0),Vector3(0.86,0.15,0.9),world.trim)
	var sign = Label3D.new()
	sign.text = "PURRINGTON HOTEL"
	sign.font = preload("res://assets/fonts/Fredoka.ttf")
	sign.font_size = 40
	sign.pixel_size = 0.011
	sign.modulate = Color("fff0cf")
	sign.position = Vector3(0,2.91,front+0.17)
	exterior.add_child(sign)
	block(exterior,Vector3(0,2.9,front+0.1),Vector3(4.75,0.67,0.16),world.trim)

func window_detail(parent: Node3D) -> void:
	block(parent,Vector3.ZERO,Vector3(1.55,1.4,0.08),world.wood.darkened(0.12))
	block(parent,Vector3(0,0,0.06),Vector3(1.3,1.15,0.06),Color("b9d6d0"))
	block(parent,Vector3(0,0,0.11),Vector3(0.08,1.2,0.06),Color("f7e8cc"))
	block(parent,Vector3(0,0,0.11),Vector3(1.32,0.08,0.06),Color("f7e8cc"))
	block(parent,Vector3(0,-0.75,0.12),Vector3(1.8,0.16,0.35),world.wood)

func _build_boundary() -> void:
	for strip in range(3):
		var open: bool = strip < world.wings
		var z: float = -18.75-strip*2.5
		block(border,Vector3(0,-0.2,z),Vector3(14.0,0.20,2.5),Color("bdd09c") if open else Color("a7b29a"))
		if open:
			block(border,Vector3(0,-0.04,z),Vector3(1.8,0.10,2.5),Color("dfccab"))
	# Property ownership and the camera limit are separate. No fence crosses a new plot.

func _process(delta: float) -> void:
	if world == null:
		return
	var visitors: Array = world.actors.duplicate()
	if world.neighborhood != null:
		for actor in [world.neighborhood.manager,world.neighborhood.maid]:
			if is_instance_valid(actor): visitors.append(actor)
	visitors.append_array(world.builders)
	for door in doors:
		door.hold = maxf(0,door.hold-delta)
		var near: bool = false
		for cat in visitors:
			if not is_instance_valid(cat) or not cat.visible:
				continue
			var offset: Vector3 = cat.global_position-door.position
			if Vector2(offset.x,offset.z).length() < 1.45:
				near = true
				break
		door.open = near or door.hold > 0
		var angle: float = -PI*0.52 if door.open else 0.0
		door.pivot.rotation.y = move_toward(door.pivot.rotation.y,angle,delta*5.5) if world.motion_enabled else angle
