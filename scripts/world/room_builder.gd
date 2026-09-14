extends Node3D
## Buildable rooms. Geometry and previews never modify the economy model.
const Layout = preload("res://scripts/core/room_layout.gd")
const Content = preload("res://scripts/core/game_content.gd")
const FurnitureRenderer = preload("res://scripts/world/furniture_renderer.gd")
const Interior = preload("res://scripts/core/furniture_layout.gd")
const Shared = preload("res://scripts/core/shared_layout.gd")
const CELL: float = 1.1
const ORIGIN = Vector3(-5.5, 0.24, -17.6)
const MINT = Color("8bdfba")
const WOOD = Color("c18c62")
const CREAM = Color("fff8e9")
const GREEN = Color("5cc8a1")
var world
var model
var room_nodes: Array = []
var _renderers: Array = []
var _furniture_keys: Array[String] = []
var _draft_room: int = -1
var _shared_renderer
var _shared_data: Dictionary = {}
var _shared_key: String = ""
var _rooms: Array = []
var _key: String = ""
var _selected: int = -1
var _floor: Node3D
var _future_floor: Node3D
var _future_garden: Node3D
var _overlay: Node3D
var _preview: Node3D
var _preview_key: String = ""
var _blueprint_renderer
var _furniture_preview: int = -1
var _materials: Dictionary = {}
var _batches: Dictionary = {}
var _cube: BoxMesh

func sync(value) -> void:
	model = value
	var hotel: int = model.current_hotel
	var rooms: Array = Layout.entries(model, hotel)
	var wings: int = int(model.hotels[hotel].wings)
	var key: String = str(hotel) + ":" + str(wings) + ":" + str(rooms)
	if key == _key:
		_sync_furniture(hotel)
		_sync_shared(hotel)
		return
	if _draft_room != -1: clear_draft()
	_key = key
	clear_preview()
	_rooms = rooms.duplicate(true)
	for node in room_nodes:
		_dispose(node)
	room_nodes.clear()
	for item_renderer in _renderers: _dispose(item_renderer)
	_renderers.clear()
	_furniture_keys.clear()
	_dispose(_floor)
	_floor = Node3D.new()
	_floor.name = "BuildableFloor"
	add_child(_floor)
	_build_grid(wings)
	for index in range(_rooms.size()):
		var node: Node3D = _make_room(_rooms[index], index)
		add_child(node)
		room_nodes.append(node)
		var item_renderer = FurnitureRenderer.new()
		item_renderer.name = "RoomFurniture%d" % index
		item_renderer.builder = self
		add_child(item_renderer)
		_renderers.append(item_renderer)
		_furniture_keys.append("")
	_sync_furniture(hotel)
	_sync_shared(hotel)
	select_room(_selected)

func _sync_furniture(hotel: int) -> void:
	if model == null: return
	for index in mini(_rooms.size(),_renderers.size()):
		if index == _draft_room: continue
		var record: Dictionary = model.furniture.room_record(hotel,index)
		var key := str(_rooms[index])+":"+str(record.get("revision",-1))
		if _furniture_keys[index] != key:
			_renderers[index].sync(_rooms[index],model.furniture.room_items(hotel,index))
			_furniture_keys[index] = key

func renderer(room: int):
	if room == -2: return _shared_renderer
	return _renderers[room] if room >= 0 and room < _renderers.size() else null

func show_draft(room: int, instances: Array):
	if room == -2:
		if _draft_room != room: clear_draft()
		_draft_room = room
		_shared_renderer.sync(_shared_data,instances)
		return _shared_renderer
	if room < 0 or room >= _renderers.size(): return null
	if _draft_room != room: clear_draft()
	_draft_room = room
	_renderers[room].sync(_rooms[room],instances)
	return _renderers[room]

func clear_draft() -> void:
	if _draft_room == -2 and is_instance_valid(_shared_renderer) and model != null:
		_shared_renderer.clear_ghost(); _shared_renderer.clear_marker()
		_shared_renderer.sync(_shared_data,model.furniture.room_items(model.current_hotel,-2))
		_shared_key = _shared_sync_key(model.current_hotel)
	if _draft_room >= 0 and _draft_room < _renderers.size() and model != null:
		_renderers[_draft_room].clear_ghost()
		_renderers[_draft_room].clear_marker()
		_renderers[_draft_room].sync(_rooms[_draft_room],model.furniture.room_items(model.current_hotel,_draft_room))
		var record: Dictionary = model.furniture.room_record(model.current_hotel,_draft_room)
		_furniture_keys[_draft_room] = str(_rooms[_draft_room])+":"+str(record.get("revision",-1))
	_draft_room = -1

func _sync_shared(hotel: int) -> void:
	_shared_data = Shared.data(model.hotels,hotel)
	if not is_instance_valid(_shared_renderer):
		_shared_renderer = FurnitureRenderer.new()
		_shared_renderer.name = "SharedFurniture"
		_shared_renderer.builder = self
		add_child(_shared_renderer)
	var key := _shared_sync_key(hotel)
	if _draft_room != -2 and key != _shared_key:
		_shared_renderer.sync(_shared_data,model.furniture.room_items(hotel,-2))
		_shared_key=key

func _shared_sync_key(hotel: int) -> String:
	var record: Dictionary=model.furniture.room_record(hotel,-2)
	return str(hotel)+":"+str(_shared_data.get("wings",0))+":"+str(_shared_data.get("layout",[]))+":"+str(record.get("revision",-1))

func room_at(screen: Vector2) -> int:
	if world == null or world.camera == null or world.exterior_view:
		return -1
	var ray: Vector3 = world.camera.project_ray_origin(screen)
	var direction: Vector3 = world.camera.project_ray_normal(screen)
	if absf(direction.y) < 0.001:
		return -1
	var point: Vector3 = ray + direction * ((0.24 - ray.y) / direction.y)
	for index in range(_rooms.size()):
		var room: Dictionary = _rooms[index]
		var size: Vector2i = Layout.dimensions(str(room.kind), int(room.rotation))
		var corner: Vector3 = ORIGIN + Vector3(float(room.x) * CELL, 0, float(room.y) * CELL)
		if point.x >= corner.x and point.x < corner.x + size.x * CELL and point.z >= corner.z and point.z < corner.z + size.y * CELL:
			return index
	return -1

func space_at(screen: Vector2) -> int:
	var room := room_at(screen)
	if room >= 0: return room
	if world == null or world.camera == null or world.exterior_view: return -1
	var ray: Vector3=world.camera.project_ray_origin(screen); var direction: Vector3=world.camera.project_ray_normal(screen)
	if absf(direction.y)<0.001: return -1
	var point:=ray+direction*((0.24-ray.y)/direction.y)
	return -2 if Shared.contains(_shared_data,point) else -1

func select_room(index: int) -> void:
	_selected = index
	_dispose(_overlay)
	_overlay = Node3D.new()
	_overlay.name = "RoomSelection"
	add_child(_overlay)
	if index >= 0 and index < _rooms.size():
		_boundary(_overlay, _rooms[index], MINT, 0.075)
		_flush(_overlay)

func preview_room(candidate: Dictionary, valid: bool) -> void:
	var key: String = str(candidate) + ":" + str(valid)
	if key == _preview_key and is_instance_valid(_preview):
		return
	clear_preview()
	if candidate.is_empty():
		return
	_preview_key = key
	_preview = _make_room(candidate, -1, true)
	_preview.name = "RoomPlacementPreview"
	add_child(_preview)
	var border: Node3D = Node3D.new()
	_preview.add_child(border)
	border.position = -_preview.position
	_boundary(border, candidate, MINT if valid else Color("ec796b"), 0.10)
	_flush(border)

func preview_blueprint(candidate: Dictionary, items: Array, valid: bool) -> void:
	var key: String = "blueprint:" + str(candidate) + ":" + str(items) + ":" + str(valid)
	if key == _preview_key and is_instance_valid(_preview) and is_instance_valid(_blueprint_renderer):
		return
	clear_preview()
	if candidate.is_empty():
		return
	_preview_key = key
	_preview = _make_room(candidate,-1,true)
	_preview.name = "RoomBlueprintPlacementPreview"
	add_child(_preview)
	var border := Node3D.new()
	_preview.add_child(border)
	border.position = -_preview.position
	_boundary(border,candidate,MINT if valid else Color("ec796b"),0.10)
	_flush(border)
	_blueprint_renderer = FurnitureRenderer.new()
	_blueprint_renderer.name = "RoomBlueprintFurniturePreview"
	_blueprint_renderer.builder = self
	add_child(_blueprint_renderer)
	var instances: Array = []
	for index in range(items.size()):
		var raw: Dictionary = items[index]
		instances.append({"uid":"blueprint-preview:%d" % index,"item":str(raw.get("item","")),
			"hotel":-1,"room":-1,"x":raw.get("x",0),"y":raw.get("y",0),"rotation":raw.get("rotation",0)})
	_blueprint_renderer.sync(candidate,instances)
	for object in _blueprint_renderer.objects.values():
		for mesh in object.get_children():
			if not mesh is GeometryInstance3D or mesh.material_override == null: continue
			var material = mesh.material_override.duplicate()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = 0.48 if valid else 0.38
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func preview_furniture(room: int, item_id: String) -> void:
	# Retained for old callers; Build owns ghost placement through the renderer.
	if room >= 0 and room < _renderers.size(): _renderers[room].select("")

func clear_preview() -> void:
	_preview_key = ""
	_dispose(_preview)
	_preview = null
	_dispose(_blueprint_renderer)
	_blueprint_renderer = null
	if _furniture_preview >= 0 and _furniture_preview < room_nodes.size() and is_instance_valid(room_nodes[_furniture_preview]):
		room_nodes[_furniture_preview].visible = true
		_furniture_preview = -1
	for item_renderer in _renderers:
		item_renderer.clear_ghost()
		item_renderer.clear_marker()
	if is_instance_valid(_shared_renderer):
		_shared_renderer.clear_ghost()
		_shared_renderer.clear_marker()

func reveal(room: int) -> void:
	if room < 0 or room >= room_nodes.size() or world == null or not world.motion_enabled:
		return
	var node: Node3D = room_nodes[room]
	node.scale = Vector3(0.94, 0.04, 0.94)
	var tween: Tween = create_tween()
	tween.tween_property(node, "scale", Vector3.ONE, 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sparkles: Node3D = Node3D.new()
	add_child(sparkles)
	var c: Vector3 = Layout.center(_rooms[room])
	for i in range(14):
		var a: float = TAU * i / 14.0
		_box(sparkles, c + Vector3(cos(a) * 1.7, 0.35 + float(i % 3) * 0.12, sin(a) * 1.3), Vector3.ONE * 0.09, Color("efcb79"))
	_flush(sparkles)
	var particles: Tween = create_tween()
	particles.tween_property(sparkles, "position:y", 1.4, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	particles.tween_callback(sparkles.queue_free)

func bed_position(room: int) -> Vector3:
	var instance := _first_item(room,true)
	return FurnitureRenderer.use_anchor(_rooms[room],instance) if not instance.is_empty() else Vector3.ZERO

func activity_position(room: int) -> Vector3:
	var instance := _first_item(room,false)
	return FurnitureRenderer.use_anchor(_rooms[room],instance) if not instance.is_empty() else Vector3.ZERO

func activity_pose(room: int) -> String:
	var instance := _first_item(room,false)
	return str(preload("res://scripts/core/furniture_catalog.gd").item(str(instance.get("item",""))).get("pose","rest"))

func _first_item(room: int, sleep: bool) -> Dictionary:
	if room < 0 or room >= _rooms.size() or model == null: return {}
	for instance in model.furniture.room_items(model.current_hotel,room):
		var definition := preload("res://scripts/core/furniture_catalog.gd").item(instance.item)
		if definition.interactive and bool(definition.provides_sleep) == sleep: return instance
	return {}

func door_position(room: int) -> Vector3:
	if room < 0 or room >= _rooms.size():
		return Vector3.ZERO
	return Interior.entrance_transition(_rooms[room]).outside

func _build_grid(wings: int) -> void:
	_future_floor = Node3D.new()
	_future_floor.name = "FutureBuildingTiles"
	_floor.add_child(_future_floor)
	_future_garden = Node3D.new()
	_future_garden.name = "QuietGardenReserve"
	_floor.add_child(_future_garden)
	var first: int = maxi(0, 9 - wings * 3)
	for row in range(12):
		for col in range(10):
			var p: Vector3 = ORIGIN + Vector3((col + 0.5) * CELL, -0.12, (row + 0.5) * CELL)
			var color: Color = Color("d6c39e") if row >= first else Color("a8af98")
			if (row + col) % 2 == 0:
				color = color.lightened(0.035)
			_box(_future_floor if row < first else _floor, p, Vector3(CELL - 0.018, 0.11, CELL - 0.018), color)
	if first > 0:
		var barrier_z: float = ORIGIN.z + first * CELL - 0.12
		for x in range(11):
			_box(_floor, Vector3(ORIGIN.x + x * CELL, 0.51, barrier_z), Vector3(0.12, 0.66, 0.15), WOOD)
		_box(_floor, Vector3(0, 0.65, barrier_z), Vector3(11, 0.17, 0.13), Color("e6c687"))
		_box(_floor, Vector3(0, 0.32, barrier_z), Vector3(11, 0.12, 0.13), Color("c29c64"))
		for wing in range(3 - wings):
			var z: float = ORIGIN.z + (first - 1.5 - wing * 3) * CELL
			_box(_future_floor, Vector3(-3.8, 0.45, z), Vector3(0.85, 0.44, 0.65), Color("bdb8a1"))
			_box(_future_floor, Vector3(-3.8, 0.70, z), Vector3(0.92, 0.10, 0.72), Color("e8dfc6"))
			_label(_future_floor, "FUTURE ROOMS", Vector3(0, 0.4, z), 34, Color("68745b"), 0.009)
		_box(_future_garden,Vector3(0,0.18,ORIGIN.z+first*CELL*0.5),Vector3(10.8,0.09,first*CELL),Color("b7cda2"))
		for index in range(7):
			_plant(_future_garden,Vector3(-4.4+index*1.45,0.23,barrier_z-0.65-0.30*(index%2)),false)
	_flush(_floor)
	_flush(_future_floor)
	_flush(_future_garden)
	_update_reserve()

func _process(_delta: float) -> void:
	_update_reserve()

func _update_reserve() -> void:
	if is_instance_valid(_future_floor):
		_future_floor.visible = is_instance_valid(world) and (world.build_mode or world.overview)
		_future_garden.visible = not _future_floor.visible

func _make_room(data: Dictionary, index: int, ghost: bool = false) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = "Suite%d" % (index + 1) if str(data.kind) == "suite" else "Room%d" % (index + 1)
	node.position = Layout.center(data)
	var dims: Vector2i = Layout.dimensions(str(data.kind), int(data.rotation))
	var w: float = dims.x * CELL
	var d: float = dims.y * CELL
	_box(node, Vector3(0, -0.055, 0), Vector3(w - 0.035, 0.12, d - 0.035), WOOD, ghost)
	var plank_count: int = int(d / 0.25)
	for plank in range(plank_count):
		var z: float = -d / 2.0 + (plank + 0.5) * d / plank_count
		_box(node, Vector3(0, 0.012, z), Vector3(w - 0.12, 0.035, d / plank_count - 0.014), Color("e6bb89") if plank % 3 == 0 else Color("d9ac7a"), ghost)
		for seam in range(2):
			var x: float = -w / 2.0 + w * (0.27 + seam * 0.44) + (0.32 if plank % 2 else 0.0)
			_box(node, Vector3(x, 0.033, z), Vector3(0.012, 0.008, d / plank_count - 0.015), Color("a47c58"), ghost)
	var room_color: Color = [Color("5cc8a1"),Color("f5a18f"),Color("ffcc68")][posmod(index,3)]
	for side in [3,2,0,1]: _wall(node,w,d,side,int(data.rotation)==side,ghost,room_color)
	# Soft curtains and a little display shelf live on the walls, clear of every placement cell.
	for z in [-0.60,0.77]:
		_box(node,Vector3(-w/2+0.24,1.48,z),Vector3(0.18,1.20,0.23),room_color.lightened(0.4),ghost)
		_box(node,Vector3(-w/2+0.35,1.30,z),Vector3(0.04,0.08,0.25),room_color,ghost)
	_box(node,Vector3(w*0.28,1.20,-d/2+0.22),Vector3(0.72,0.10,0.35),WOOD,ghost)
	for book in range(3):
		_box(node,Vector3(w*0.28-0.22+book*0.17,1.43,-d/2+0.21),Vector3(0.12,0.35+book*0.025,0.20),[room_color,Color("ffcc68"),CREAM][book],ghost)
	# Framed botanical prints and a wide window make the cutaway feel inhabited.
	if int(data.rotation) != 3:
		for x in [-0.65, 0.30]:
			_box(node, Vector3(x, 1.46, -d / 2.0 + 0.13), Vector3(0.68, 0.75, 0.07), Color("9b754f"), ghost)
			_box(node, Vector3(x, 1.46, -d / 2.0 + 0.175), Vector3(0.56, 0.63, 0.025), Color("fff5dc"), ghost)
			_box(node, Vector3(x, 1.41, -d / 2.0 + 0.194), Vector3(0.045, 0.36, 0.025), GREEN, ghost)
			_box(node, Vector3(x - 0.10, 1.51, -d / 2.0 + 0.20), Vector3(0.18, 0.14, 0.025), Color("9fae77"), ghost)
			_box(node, Vector3(x + 0.10, 1.39, -d / 2.0 + 0.20), Vector3(0.18, 0.13, 0.025), Color("7c946d"), ghost)
	if int(data.rotation) != 2:
		_box(node, Vector3(-w / 2.0 + 0.115, 1.40, 0.08), Vector3(0.07, 1.0, 1.25), Color("fdf1d5"), ghost)
		_box(node, Vector3(-w / 2.0 + 0.16, 1.40, 0.08), Vector3(0.03, 0.81, 1.04), Color("b6d6cc"), ghost)
		_box(node, Vector3(-w / 2.0 + 0.19, 1.40, 0.08), Vector3(0.055, 0.05, 1.12), CREAM, ghost)
		_box(node, Vector3(-w / 2.0 + 0.19, 1.40, 0.08), Vector3(0.055, 0.86, 0.055), CREAM, ghost)
		_box(node, Vector3(-w / 2.0 + 0.24, 0.92, 0.08), Vector3(0.30, 0.09, 1.37), CREAM, ghost)
	_flush(node)
	return node

func _wall(node: Node3D, w: float, d: float, side: int, door: bool, ghost: bool, room_color: Color = GREEN) -> void:
	var along_x: bool = side == 1 or side == 3
	var length: float = w if along_x else d
	var tall: bool = side == 2 or side == 3
	var h: float = 2.08 if tall else 0.17
	var fixed: float = (d / 2.0 if side == 1 else -d / 2.0) if along_x else (w / 2.0 if side == 0 else -w / 2.0)
	var spans: Array = [[0.0, length]]
	if door:
		spans = [[-(length + 0.94) / 4.0, (length - 0.94) / 2.0], [(length + 0.94) / 4.0, (length - 0.94) / 2.0]]
	for span in spans:
		var p: Vector3 = Vector3(float(span[0]), h / 2.0, fixed) if along_x else Vector3(fixed, h / 2.0, float(span[0]))
		var size: Vector3 = Vector3(float(span[1]), h, 0.13) if along_x else Vector3(0.13, h, float(span[1]))
		_box(node, p, size, CREAM, ghost)
		p.y = 0.35 if tall else 0.07
		size.y = 0.68 if tall else 0.13
		size.z += 0.018 if along_x else 0.0
		size.x += 0.0 if along_x else 0.018
		_box(node, p, size, room_color.lightened(0.15), ghost)
		p.y = 0.72 if tall else 0.18
		size.y = 0.055
		_box(node, p, size, Color("d8d6ad"), ghost)
		if tall:
			p.y = h + 0.025
			size.y = 0.095
			_box(node, p, size, Color("fff0d0"), ghost)
			var divisions: int = maxi(1, int(float(span[1]) / 0.5))
			for i in range(divisions):
				var coordinate: float = float(span[0]) - float(span[1]) / 2.0 + (i + 0.5) * float(span[1]) / divisions
				var rail: Vector3 = Vector3(coordinate, 0.36, fixed) if along_x else Vector3(fixed, 0.36, coordinate)
				_box(node, rail, Vector3(0.035, 0.60, 0.16) if along_x else Vector3(0.16, 0.60, 0.035), room_color.lightened(0.38), ghost)
	if door and tall:
		var lintel: Vector3 = Vector3(0, 1.98, fixed) if along_x else Vector3(fixed, 1.98, 0)
		_box(node, lintel, Vector3(1.04, 0.20, 0.18) if along_x else Vector3(0.18, 0.20, 1.04), CREAM, ghost)

func _bed(node: Node3D, p: Vector3, item: String, ghost: bool) -> void:
	var bedding: Color = Color("ffcc68")
	match item:
		"sun_cushion": bedding = Color("e8bd65")
		"cave": bedding = Color("ae9695")
		"heated": bedding = Color("ecc8ab")
		"blanket": bedding = Color("5cc8a1")
	for x in [-0.57, 0.57]:
		for z in [-0.65, 0.65]:
			_box(node, p + Vector3(x, 0.14, z), Vector3(0.13, 0.27, 0.13), Color("856346"), ghost)
	_box(node, p + Vector3(0, 0.27, 0), Vector3(1.45, 0.19, 1.77), WOOD, ghost)
	_box(node, p + Vector3(0, 0.69, -0.84), Vector3(1.49, 1.0, 0.13), Color("ae8660"), ghost)
	_box(node, p + Vector3(0, 0.75, -0.755), Vector3(1.22, 0.56, 0.07), Color("d5b590"), ghost)
	_box(node, p + Vector3(0, 0.44, 0), Vector3(1.36, 0.23, 1.64), Color("fff3de"), ghost)
	_box(node, p + Vector3(0, 0.57, 0.26), Vector3(1.39, 0.13, 1.15), bedding, ghost)
	# Raised gingham squares read as a plush quilt even at the hotel camera distance.
	for row in range(4):
		for col in range(5):
			_box(node,p+Vector3(-0.55+col*0.275,0.648,-0.16+row*0.275),Vector3(0.265,0.03,0.265),bedding.lightened(0.30) if (row+col)%2==0 else bedding,ghost)
	_box(node, p + Vector3(0, 0.62, -0.23), Vector3(1.41, 0.085, 0.24), bedding.lightened(0.20), ghost)
	for x in [-0.35, 0.35]:
		_box(node, p + Vector3(x, 0.61, -0.53), Vector3(0.56, 0.17, 0.38), Color("fff8e9"), ghost)
	if item == "cave":
		for x in [-0.68, 0.68]:
			_box(node, p + Vector3(x, 0.94, -0.36), Vector3(0.12, 0.83, 0.86), bedding, ghost)
		_box(node, p + Vector3(0, 1.37, -0.36), Vector3(1.48, 0.14, 0.92), bedding.lightened(0.16), ghost)
	elif item == "heated":
		_box(node, p + Vector3(0, 0.36, 0.895), Vector3(1.20, 0.05, 0.025), Color("ffcf77"), ghost)
		_box(node, p + Vector3(0.53, 0.66, 0.51), Vector3(0.16, 0.06, 0.23), Color("bb967f"), ghost)
	elif item == "blanket":
		for z in [0.04, 0.37, 0.70]:
			_box(node, p + Vector3(0, 0.645, z), Vector3(1.41, 0.023, 0.08), Color("e4d5af"), ghost)
	elif item == "sun_cushion":
		_box(node, p + Vector3(0, 0.72, 0.25), Vector3(0.67, 0.20, 0.62), Color("f4d880"), ghost)

func _nightstand(node: Node3D, p: Vector3, ghost: bool) -> void:
	_box(node, p + Vector3(0, 0.27, 0), Vector3(0.48, 0.52, 0.49), WOOD, ghost)
	_box(node, p + Vector3(0, 0.56, 0), Vector3(0.54, 0.07, 0.54), Color("d2ae7d"), ghost)
	_box(node, p + Vector3(0, 0.40, 0.25), Vector3(0.34, 0.17, 0.02), Color("be9166"), ghost)
	_box(node, p + Vector3(0, 0.40, 0.28), Vector3(0.10, 0.035, 0.05), Color("e4c986"), ghost)
	_lamp(node, p + Vector3(0, 0.61, 0), false, ghost)

func _item(node: Node3D, item: String, p: Vector3, ghost: bool) -> void:
	match item:
		"box":
			_box(node, p + Vector3(0, 0.10, 0), Vector3(0.94, 0.16, 0.77), Color("ad7b51"), ghost)
			for x in [-0.43, 0.43]:
				_box(node, p + Vector3(x, 0.38, 0), Vector3(0.08, 0.57, 0.77), Color("c59a68"), ghost)
			for z in [-0.35, 0.35]:
				_box(node, p + Vector3(0, 0.38, z), Vector3(0.94, 0.57, 0.08), Color("d2ac78"), ghost)
			_box(node, p + Vector3(-0.58, 0.67, 0), Vector3(0.32, 0.045, 0.74), Color("d2ac78"), ghost)
			_box(node, p + Vector3(0.05, 0.42, 0.40), Vector3(0.39, 0.20, 0.018), Color("f3e4c4"), ghost)
		"perch":
			_box(node, p + Vector3(0, 0.08, 0), Vector3(0.90, 0.12, 0.65), WOOD, ghost)
			for x in [-0.31, 0.31]:
				_box(node, p + Vector3(x, 0.54, 0), Vector3(0.13, 0.94, 0.17), Color("bdad82"), ghost)
			_box(node, p + Vector3(0, 1.04, 0), Vector3(1.10, 0.13, 0.73), Color("bb9971"), ghost)
			_box(node, p + Vector3(0, 1.14, 0), Vector3(0.98, 0.13, 0.63), Color("e9cf8f"), ghost)
		"tunnel":
			_box(node, p + Vector3(0, 0.06, 0), Vector3(1.16, 0.10, 0.75), Color("ad8f7e"), ghost)
			for z in [-0.33, 0.33]:
				_box(node, p + Vector3(0, 0.35, z), Vector3(1.16, 0.55, 0.14), Color("bb9c87"), ghost)
			_box(node, p + Vector3(0, 0.65, 0), Vector3(1.16, 0.15, 0.75), Color("cdb199"), ghost)
			for x in [-0.44, 0.44]:
				_box(node, p + Vector3(x, 0.71, 0), Vector3(0.09, 0.07, 0.80), Color("ddd0ac"), ghost)
		"tower":
			_box(node, p + Vector3(0, 0.075, 0), Vector3(1.03, 0.15, 0.88), GREEN, ghost)
			for x in [-0.30, 0.30]:
				_box(node, p + Vector3(x, 0.68, 0), Vector3(0.16, 1.18, 0.16), Color("c4b08a"), ghost)
			_box(node, p + Vector3(-0.22, 0.69, 0.16), Vector3(0.69, 0.13, 0.69), Color("b3ba91"), ghost)
			_box(node, p + Vector3(0.24, 1.28, -0.05), Vector3(0.72, 0.16, 0.73), Color("bdc39b"), ghost)
			_box(node, p + Vector3(0.24, 1.40, -0.05), Vector3(0.59, 0.09, 0.59), Color("eee0b8"), ghost)
			_box(node, p + Vector3(-0.29, 0.48, 0.40), Vector3(0.31, 0.25, 0.27), Color("ceaf72"), ghost)
		"table":
			_table(node, p, Vector2(1.07, 0.76), 0.60, ghost)
			for z in [-0.56, 0.56]:
				_box(node, p + Vector3(0, 0.32, z), Vector3(1.06, 0.10, 0.23), Color("bf986c"), ghost)
				for x in [-0.36, 0.36]:
					_box(node, p + Vector3(x, 0.17, z), Vector3(0.09, 0.30, 0.16), WOOD, ghost)
			_box(node, p + Vector3(0.14, 0.68, 0), Vector3(0.30, 0.08, 0.30), Color("ece0c4"), ghost)
		"plant": _plant(node, p, ghost)
		"rug": _rug(node, p, Vector2(1.40, 1.18), Color("adbdaf"), ghost)
		"scratch":
			_box(node, p + Vector3(0, 0.08, 0), Vector3(0.74, 0.13, 0.67), WOOD, ghost)
			_box(node, p + Vector3(0, 0.62, 0), Vector3(0.28, 1.0, 0.28), Color("d0b58b"), ghost)
			for i in range(10):
				_box(node, p + Vector3(0, 0.20 + i * 0.09, 0), Vector3(0.30, 0.025, 0.30), Color("b79a70"), ghost)
			_box(node, p + Vector3(0, 1.14, 0), Vector3(0.41, 0.10, 0.41), GREEN, ghost)
		"lamp": _lamp(node, p, true, ghost)
		"flowers":
			_table(node, p, Vector2(0.62, 0.58), 0.48, ghost)
			_box(node, p + Vector3(0, 0.69, 0), Vector3(0.29, 0.34, 0.29), Color("b2c5b7"), ghost)
			for i in range(5):
				var x: float = float(i % 3 - 1) * 0.16
				var z: float = float(i / 3) * 0.17 - 0.09
				_box(node, p + Vector3(x, 0.97, z), Vector3(0.035, 0.46, 0.035), GREEN, ghost)
				_box(node, p + Vector3(x, 1.13 + (i % 2) * 0.11, z), Vector3(0.23, 0.17, 0.22), Color("d99886") if i % 2 else Color("edce86"), ghost)

func _plant(node: Node3D, p: Vector3, ghost: bool) -> void:
	_box(node, p + Vector3(0, 0.24, 0), Vector3(0.47, 0.45, 0.47), Color("c58f6c"), ghost)
	_box(node, p + Vector3(0, 0.47, 0), Vector3(0.53, 0.09, 0.53), Color("d9a781"), ghost)
	_box(node, p + Vector3(0, 0.73, 0), Vector3(0.08, 0.55, 0.08), Color("7e8757"), ghost)
	for leaf in [Vector3(-0.22, 0.88, 0), Vector3(0.19, 1.04, 0.08), Vector3(0, 1.20, -0.14), Vector3(0.02, 0.85, 0.22)]:
		_box(node, p + leaf, Vector3(0.38, 0.23, 0.35), GREEN if leaf.y < 1.0 else Color("a4b27c"), ghost)

func _lamp(node: Node3D, p: Vector3, floor_lamp: bool, ghost: bool) -> void:
	var h: float = 1.12 if floor_lamp else 0.25
	_box(node, p + Vector3(0, 0.04, 0), Vector3(0.39 if floor_lamp else 0.24, 0.07, 0.39 if floor_lamp else 0.24), Color("987d4e"), ghost)
	_box(node, p + Vector3(0, h / 2.0, 0), Vector3(0.055, h, 0.055), Color("a68b55"), ghost)
	_box(node, p + Vector3(0, h + 0.09, 0), Vector3(0.52 if floor_lamp else 0.34, 0.30 if floor_lamp else 0.23, 0.52 if floor_lamp else 0.34), Color("ffe2a2"), ghost)
	_box(node, p + Vector3(0, h + 0.25, 0), Vector3(0.38 if floor_lamp else 0.26, 0.04, 0.38 if floor_lamp else 0.26), Color("f1d6a0"), ghost)

func _rug(node: Node3D, p: Vector3, size: Vector2, color: Color, ghost: bool) -> void:
	_box(node, p + Vector3(0, 0.042, 0), Vector3(size.x, 0.025, size.y), color.darkened(0.12), ghost)
	_box(node, p + Vector3(0, 0.058, 0), Vector3(size.x - 0.13, 0.014, size.y - 0.13), color, ghost)
	for x in [-size.x / 2.0 + 0.15, size.x / 2.0 - 0.15]:
		_box(node, p + Vector3(x, 0.069, 0), Vector3(0.035, 0.012, size.y - 0.20), Color("ede0bf"), ghost)
	for i in range(7):
		var x: float = -size.x / 2.0 + 0.15 + i * (size.x - 0.3) / 6.0
		for z in [-size.y / 2.0, size.y / 2.0]:
			_box(node, p + Vector3(x, 0.038, z), Vector3(0.05, 0.018, 0.13), Color("e7d7b3"), ghost)

func _table(node: Node3D, p: Vector3, size: Vector2, h: float, ghost: bool) -> void:
	_box(node, p + Vector3(0, h, 0), Vector3(size.x, 0.10, size.y), Color("c79e70"), ghost)
	for x in [-size.x * 0.35, size.x * 0.35]:
		for z in [-size.y * 0.32, size.y * 0.32]:
			_box(node, p + Vector3(x, h / 2.0, z), Vector3(0.085, h, 0.085), Color("96704d"), ghost)

func _sofa(node: Node3D, p: Vector3, ghost: bool) -> void:
	_box(node, p + Vector3(0, 0.25, 0), Vector3(0.93, 0.25, 1.55), Color("748c75"), ghost)
	_box(node, p + Vector3(-0.36, 0.66, 0), Vector3(0.22, 0.69, 1.58), Color("8fa286"), ghost)
	for z in [-0.72, 0.72]:
		_box(node, p + Vector3(0, 0.52, z), Vector3(0.96, 0.46, 0.20), Color("8fa286"), ghost)
	for z in [-0.34, 0.34]:
		_box(node, p + Vector3(0.07, 0.44, z), Vector3(0.64, 0.19, 0.63), Color("a4b296"), ghost)
		_box(node, p + Vector3(-0.14, 0.70, z), Vector3(0.20, 0.35, 0.35), Color("e3c489") if z < 0 else Color("e0b7a0"), ghost)

func _boundary(node: Node3D, room: Dictionary, color: Color, thickness: float) -> void:
	var dims: Vector2i = Layout.dimensions(str(room.kind), int(room.rotation))
	var c: Vector3 = Layout.center(room)
	var w: float = dims.x * CELL
	var d: float = dims.y * CELL
	# Follow the actual cutaway silhouette instead of burying the line in the floor.
	var high: float = 2.19
	var low: float = 0.26
	_box(node, c + Vector3(-w / 2.0, high, 0), Vector3(thickness, 0.075, d), color, false, true)
	_box(node, c + Vector3(0, high, -d / 2.0), Vector3(w, 0.075, thickness), color, false, true)
	_box(node, c + Vector3(w / 2.0, low, 0), Vector3(thickness, 0.075, d), color, false, true)
	_box(node, c + Vector3(0, low, d / 2.0), Vector3(w, 0.075, thickness), color, false, true)
	for corner in [Vector2(-w / 2.0, -d / 2.0), Vector2(-w / 2.0, d / 2.0), Vector2(w / 2.0, -d / 2.0), Vector2(w / 2.0, d / 2.0)]:
		var tall: bool = corner.x < 0 or corner.y < 0
		var h: float = high if tall else low
		_box(node, c + Vector3(corner.x, h, corner.y), Vector3(0.22, 0.10, 0.22), color.lightened(0.18), false, true)
		if tall and not (corner.x < 0 and corner.y < 0):
			_box(node, c + Vector3(corner.x, (high + low) / 2.0, corner.y), Vector3(thickness, high - low, thickness), color, false, true)
	var entrance: Vector3 = Vector3(w / 2.0, 0, 0)
	match int(room.rotation):
		1: entrance = Vector3(0, 0, d / 2.0)
		2: entrance = Vector3(-w / 2.0, 0, 0)
		3: entrance = Vector3(0, 0, -d / 2.0)
	_box(node, c + entrance + Vector3(0, low, 0), Vector3(0.49, 0.08, 0.49), color.lightened(0.18), false, true)

func _label(node: Node3D, caption: String, p: Vector3, font_size: int, color: Color, pixel_size: float) -> void:
	var label: Label3D = Label3D.new()
	label.text = caption
	label.position = p
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_modulate = Color("52694f")
	label.outline_size = 7
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	node.add_child(label)

func _box(node: Node3D, p: Vector3, size: Vector3, color: Color, ghost: bool = false, overlay: bool = false) -> void:
	var id: int = node.get_instance_id()
	if not _batches.has(id):
		_batches[id] = {}
	var key: String = color.to_html() + ("ghost" if ghost else "solid") + ("overlay" if overlay else "")
	if not _batches[id].has(key):
		_batches[id][key] = {"color": color, "ghost": ghost, "overlay": overlay, "transforms": []}
	_batches[id][key].transforms.append(Transform3D(Basis.from_scale(size), p))

func _flush(node: Node3D) -> void:
	var id: int = node.get_instance_id()
	if not _batches.has(id):
		return
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	for key in _batches[id]:
		var batch: Dictionary = _batches[id][key]
		if not _materials.has(key):
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.albedo_color = batch.color
			material.roughness = 0.88
			if batch.overlay:
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.no_depth_test = true
				material.render_priority = 2
			if batch.ghost:
				material.albedo_color = batch.color.lerp(MINT, 0.32)
				material.albedo_color.a = 0.42
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
			_materials[key] = material
		var mesh: MultiMesh = MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = _cube
		mesh.instance_count = batch.transforms.size()
		for i in range(mesh.instance_count):
			mesh.set_instance_transform(i, batch.transforms[i])
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.multimesh = mesh
		instance.material_override = _materials[key]
		if batch.ghost or batch.overlay:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(instance)
	_batches.erase(id)

func _dispose(node) -> void:
	if is_instance_valid(node):
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.queue_free()
