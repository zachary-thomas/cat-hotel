extends RefCounted
## Pure interior-grid placement, transforms, and access paths.

const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const RoomLayout = preload("res://scripts/core/room_layout.gd")
const SharedLayout = preload("res://scripts/core/shared_layout.gd")
const CELL_SIZE := 0.55
const STEPS: Array[Vector2i] = [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const REGULAR_CAP := 16
const SUITE_CAP := 24
const BODY_RADIUS := 0.18
const CLEARANCE := 0.04
static var _template_cache: Dictionary = {}

static func dimensions(kind: String) -> Vector2i:
	if kind == "shared": return SharedLayout.DIMENSIONS
	return Vector2i(8,10 if kind == "suite" else 6)

static func rotate_cell(cell: Vector2i, size: Vector2i, turns: int) -> Vector2i:
	match posmod(turns,4):
		0: return cell
		1: return Vector2i(size.y - 1 - cell.y, cell.x)
		2: return Vector2i(size.x - 1 - cell.x, size.y - 1 - cell.y)
		_: return Vector2i(cell.y, size.x - 1 - cell.x)

static func _rotated_point(point: Vector2, size: Vector2i, turns: int) -> Vector2:
	match posmod(turns,4):
		0: return point
		1: return Vector2(float(size.y) - point.y, point.x)
		2: return Vector2(float(size.x) - point.x, float(size.y) - point.y)
		_: return Vector2(point.y, float(size.x) - point.x)

static func footprint(instance: Dictionary) -> Array[Vector2i]:
	var definition: Dictionary = Catalog.item(str(instance.get("item","")))
	var result: Array[Vector2i] = []
	if definition.is_empty(): return result
	var size: Vector2i = definition.footprint
	var turns := int(instance.get("rotation",0))
	var origin := Vector2i(int(instance.get("x",0)),int(instance.get("y",0)))
	for y in range(size.y):
		for x in range(size.x): result.append(origin + rotate_cell(Vector2i(x,y),size,turns))
	return result

static func local_to_world(room: Dictionary, cell: Vector2) -> Vector3:
	if str(room.get("kind","")) == "shared": return SharedLayout.local_to_world(cell)
	var size := dimensions(str(room.get("kind","regular")))
	var offset := Vector3((cell.x - size.x * 0.5) * CELL_SIZE,0.0,(cell.y - size.y * 0.5) * CELL_SIZE)
	return RoomLayout.center(room) + Basis(Vector3.UP,-int(room.get("rotation",0)) * PI * 0.5) * offset

static func world_to_local(room: Dictionary, point: Vector3) -> Vector2:
	if str(room.get("kind","")) == "shared": return SharedLayout.world_to_local(point)
	var size := dimensions(str(room.get("kind","regular")))
	var offset: Vector3 = Basis(Vector3.UP,int(room.get("rotation",0)) * PI * 0.5) * (point - RoomLayout.center(room))
	return Vector2(offset.x / CELL_SIZE + size.x * 0.5,offset.z / CELL_SIZE + size.y * 0.5)

static func entrance_transition(room: Dictionary) -> Dictionary:
	var y := 5.0 if str(room.get("kind","regular")) == "suite" else 3.0
	return {"outside":local_to_world(room,Vector2(8.0,y)),"inside":local_to_world(room,Vector2(7.5,y)),"cells":[Vector2i(7,int(y)-1),Vector2i(7,int(y))]}

static func _apron(kind: String) -> Array[Vector2i]:
	var middle := 4 if kind == "suite" else 2
	return [Vector2i(6,middle),Vector2i(7,middle),Vector2i(6,middle+1),Vector2i(7,middle+1)]

static func _result(ok: bool, code: String, message: String, blocked: Array = []) -> Dictionary:
	return {"ok":ok,"code":code,"message":message,"blocked":blocked,"paths":{},"housekeeping":Vector2i(-1,-1)}

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func _path_map(kind: String, occupied: Dictionary) -> Dictionary:
	var parents: Dictionary = {}
	var queue: Array[Vector2i] = []
	var middle := 4 if kind == "suite" else 2
	for cell in [Vector2i(7,middle),Vector2i(7,middle+1)]:
		if not occupied.has(cell) and not parents.has(cell):
			parents[cell] = cell; queue.append(cell)
	var size := dimensions(kind)
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]; cursor += 1
		for step in STEPS:
			var neighbor := cell + step
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= size.x or neighbor.y >= size.y: continue
			if occupied.has(neighbor) or parents.has(neighbor): continue
			parents[neighbor] = cell; queue.append(neighbor)
	return parents

static func _path_to(cell: Vector2i, parents: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not parents.has(cell): return result
	while true:
		result.push_front(cell)
		if parents[cell] == cell: break
		cell = parents[cell]
	return result

static func _approaches(instance: Dictionary, definition: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size: Vector2i = definition.footprint
	var turns := int(instance.rotation)
	var origin := Vector2i(int(instance.x),int(instance.y))
	for approach in definition.approaches:
		result.append(origin + rotate_cell(approach,size,turns))
	return result

static func validate(room: Dictionary, instances: Array, require_bed: bool = true) -> Dictionary:
	var kind := str(room.get("kind",""))
	if kind == "shared": return SharedLayout.validate(room,instances,false)
	if kind not in ["regular","suite"]: return _result(false,"invalid_room","Choose a regular room or suite.")
	var cap := SUITE_CAP if kind == "suite" else REGULAR_CAP
	if instances.size() > cap: return _result(false,"room_full","This room is full.")
	var floor_cells: Dictionary = {}; var rug_cells: Dictionary = {}; var definitions: Dictionary = {}; var seen_uids: Dictionary = {}
	var size := dimensions(kind)
	for value in instances:
		if not value is Dictionary: return _result(false,"invalid_item","Choose a valid furniture item.")
		var instance: Dictionary = value
		var definition := Catalog.item(str(instance.get("item","")))
		var uid := str(instance.get("uid",""))
		if definition.is_empty() or uid.is_empty() or seen_uids.has(uid): return _result(false,"invalid_item","Choose a valid furniture item.")
		if not _whole(instance.get("x")) or not _whole(instance.get("y")) or not _whole(instance.get("rotation")) or int(instance.rotation) < 0 or int(instance.rotation) > 3:
			return _result(false,"invalid_item","Choose a valid furniture position.")
		seen_uids[uid]=true; definitions[uid]=definition
		var cells := footprint(instance)
		for cell in cells:
			if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y: return _result(false,"outside","Keep the whole object inside this room.",cells)
			var layer_cells: Dictionary = rug_cells if definition.layer == "rug" else floor_cells
			if layer_cells.has(cell): return _result(false,"overlap","Another object is here.",[cell])
			layer_cells[cell]=uid
	for cell in _apron(kind):
		if floor_cells.has(cell): return _result(false,"door_blocked","Keep the doorway clear.",[cell])
	var parents := _path_map(kind,floor_cells)
	var paths: Dictionary = {}; var reachable_bed := false
	for value in instances:
		var instance: Dictionary = value; var uid := str(instance.uid); var definition: Dictionary = definitions[uid]
		if not definition.interactive: continue
		var best: Array[Vector2i] = []
		for approach in _approaches(instance,definition):
			var candidate := _path_to(approach,parents)
			if not candidate.is_empty() and (best.is_empty() or candidate.size() < best.size()): best=candidate
		if best.is_empty(): return _result(false,"unreachable_bed" if definition.provides_sleep else "unreachable_object","Cats can't reach this object.",_approaches(instance,definition))
		paths[uid]=best
		if definition.provides_sleep: reachable_bed=true
	if require_bed and not reachable_bed: return _result(false,"missing_bed","Add a bed cats can reach.")
	var housekeeping := Vector2i(-1,-1); var center := Vector2(size) * 0.5
	var center_cell := Vector2i(floori(center.x),floori(center.y))
	if parents.has(center_cell): housekeeping=center_cell
	for cell in parents:
		if housekeeping == center_cell: break
		var distance := Vector2(cell).distance_squared_to(center)
		var old_distance := Vector2(housekeeping).distance_squared_to(center) if housekeeping.x >= 0 else INF
		if distance < old_distance or (is_equal_approx(distance,old_distance) and (cell.y < housekeeping.y or (cell.y == housekeeping.y and cell.x < housekeeping.x))): housekeeping=cell
	if housekeeping.x < 0: return _result(false,"housekeeping_blocked","Leave a reachable place for housekeeping.")
	return {"ok":true,"code":"","message":"Ready to apply.","blocked":[],"paths":paths,"housekeeping":housekeeping}

static func route_to(room: Dictionary, instances: Array, uid: String) -> Array[Vector3]:
	var validation := validate(room,instances,false); var result: Array[Vector3] = []
	if not validation.ok or not validation.paths.has(uid): return result
	var instance: Dictionary = {}
	for value in instances:
		if str(value.get("uid","")) == uid: instance=value; break
	if instance.is_empty(): return result
	result.append(entrance_transition(room).inside)
	for cell in validation.paths[uid]: result.append(local_to_world(room,Vector2(cell)+Vector2(0.5,0.5)))
	var definition := Catalog.item(str(instance.item)); var target: Vector3 = definition.animation_target
	var local_target := Vector2(instance.x,instance.y) + _rotated_point(Vector2(target.x,target.z),definition.footprint,int(instance.rotation))
	var world_target := local_to_world(room,local_target); world_target.y += target.y
	result.append(world_target)
	return result

static func housekeeping_world(room: Dictionary, instances: Array) -> Vector3:
	var validation := validate(room,instances,false)
	if not validation.ok or validation.housekeeping.x < 0: return Vector3.ZERO
	var center := Vector2(dimensions(str(room.kind))) * 0.5
	if validation.housekeeping == Vector2i(floori(center.x),floori(center.y)): return local_to_world(room,center)
	return local_to_world(room,Vector2(validation.housekeeping)+Vector2(0.5,0.5))

static func route_to_housekeeping(room: Dictionary, instances: Array) -> Array[Vector3]:
	var validation := validate(room,instances,false); var result: Array[Vector3] = []
	if not validation.ok: return result
	result.append(entrance_transition(room).inside)
	for cell in _path_to(validation.housekeeping,_path_map(str(room.kind),_floor_occupied(instances))): result.append(local_to_world(room,Vector2(cell)+Vector2(0.5,0.5)))
	var target := housekeeping_world(room,instances)
	if result.is_empty() or not result[-1].is_equal_approx(target): result.append(target)
	return result

static func _floor_occupied(instances: Array) -> Dictionary:
	var occupied: Dictionary = {}
	for instance in instances:
		if Catalog.item(str(instance.get("item",""))).get("layer","") == "floor":
			for cell in footprint(instance): occupied[cell]=true
	return occupied

static func movement_guard(room: Dictionary, instances: Array) -> Callable:
	var occupied: Dictionary = _floor_occupied(instances)
	var size := dimensions(str(room.get("kind","regular")))
	var clearance := (BODY_RADIUS+CLEARANCE)/CELL_SIZE
	return func(start: Vector3, finish: Vector3) -> bool:
		var length := start.distance_to(finish)
		var samples := maxi(1,ceili(length / 0.08))
		for index in range(samples+1):
			var local := world_to_local(room,start.lerp(finish,float(index)/samples))
			if local.x < clearance or local.y < clearance or local.x > size.x-clearance or local.y > size.y-clearance: return false
			for x in range(floori(local.x-clearance),floori(local.x+clearance)+1):
				for y in range(floori(local.y-clearance),floori(local.y+clearance)+1):
					if not occupied.has(Vector2i(x,y)): continue
					var closest := Vector2(clampf(local.x,x,x+1),clampf(local.y,y,y+1))
					if local.distance_squared_to(closest)<clearance*clearance: return false
		return true

static func _record(item: String, x: int, y: int, rotation: int) -> Dictionary:
	return {"item":item,"x":x,"y":y,"rotation":rotation}

static func _records_for_validation(values: Array) -> Array:
	var result: Array = []
	for index in values.size():
		var value: Dictionary = values[index].duplicate(); value.uid="template:%d" % index; value.hotel=0; value.room=0; result.append(value)
	return result

static func _search(kind: String, ids: Array, index: int, values: Array) -> bool:
	if index >= ids.size(): return validate({"kind":kind,"x":0,"y":0,"rotation":0},_records_for_validation(values)).ok
	var definition := Catalog.item(str(ids[index])); var room_size := dimensions(kind)
	for y in range(room_size.y):
		for x in range(room_size.x):
			for rotation in range(4):
				if rotation > 1 and definition.footprint.x == definition.footprint.y: continue
				values.append(_record(str(ids[index]),x,y,rotation))
				if validate({"kind":kind,"x":0,"y":0,"rotation":0},_records_for_validation(values),false).ok and _search(kind,ids,index+1,values): return true
				values.pop_back()
	return false

static func template(kind: String, legacy_items: Array = []) -> Array:
	if kind not in ["regular","suite"]: return []
	var cache_key := kind + ":" + ",".join(legacy_items)
	if _template_cache.has(cache_key): return _template_cache[cache_key].duplicate(true)
	var values: Array = []
	if legacy_items.is_empty():
		values = [_record("mat",0,0,0),_record("box",4,0,0),_record("plant",7,0,0),_record("room_nightstand",3,0,0)]
		if kind == "suite": values.append_array([_record("suite_sofa",0,7,0),_record("suite_table",4,7,0)])
	else:
		var ids: Array = legacy_items.duplicate()
		ids.append("room_nightstand")
		if kind == "suite": ids.append_array(["suite_sofa","suite_table"])
		if not _search(kind,ids,0,values): return []
	_template_cache[cache_key]=values.duplicate(true)
	return values
