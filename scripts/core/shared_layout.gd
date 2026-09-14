extends RefCounted
## Bounded furniture space shared by the lobby and unlocked guest-floor aisles.
## Coordinates use the same 0.55-unit cells as bedrooms, rooted at the
## north-west corner of RoomLayout's complete building grid.

const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const Rooms = preload("res://scripts/core/room_layout.gd")
const DIMENSIONS := Vector2i(20,42)
const CELL_SIZE := 0.55
const ORIGIN := Vector3(-5.5,0.24,-17.6)
const CAP := 48
# VoxelCat scale 1.12 × CatNavigation radius 0.60, plus its 0.06 gap.
const ACTOR_CLEARANCE := 0.732
const FRONT_WALL_Z := 4.59
static var _fixed_cache: Dictionary = {}
const STEPS: Array[Vector2i] = [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]

static func data(hotels: Array, hotel: int) -> Dictionary:
	if hotel < 0 or hotel >= hotels.size() or not hotels[hotel] is Dictionary: return {}
	var source: Dictionary = hotels[hotel]
	return {"kind":"shared","x":0,"y":0,"rotation":0,"hotel":hotel,
		"wings":clampi(int(source.get("wings",0)),0,3),"layout":Array(source.get("layout",[])).duplicate(true)}

static func validator(hotels: Array, hotel: int) -> Callable:
	var shared := data(hotels,hotel)
	return func(instances: Array) -> Dictionary: return validate(shared,instances,false)

static func local_to_world(cell: Vector2) -> Vector3:
	return ORIGIN + Vector3(cell.x*CELL_SIZE,0,cell.y*CELL_SIZE)

static func world_to_local(point: Vector3) -> Vector2:
	return Vector2((point.x-ORIGIN.x)/CELL_SIZE,(point.z-ORIGIN.z)/CELL_SIZE)

static func contains(value: Dictionary, point: Variant) -> bool:
	var local: Vector2 = world_to_local(Vector3(point.x,0.24,point.y) if point is Vector2 else point)
	return local.x >= 0 and local.y >= 0 and local.x < DIMENSIONS.x and local.y < DIMENSIONS.y and _reason_with(value,Vector2i(floori(local.x),floori(local.y)),_masks(value)).is_empty()

static func _rotate(cell: Vector2i, size: Vector2i, turns: int) -> Vector2i:
	match posmod(turns,4):
		0: return cell
		1: return Vector2i(size.y-1-cell.y,cell.x)
		2: return Vector2i(size.x-1-cell.x,size.y-1-cell.y)
		_: return Vector2i(cell.y,size.x-1-cell.x)

static func _footprint(instance: Dictionary, definition: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []; var size: Vector2i = definition.footprint
	var origin := Vector2i(int(instance.get("x",0)),int(instance.get("y",0)))
	for y in range(size.y):
		for x in range(size.x): result.append(origin+_rotate(Vector2i(x,y),size,int(instance.get("rotation",0))))
	return result

static func _room_cells(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for room in value.get("layout",[]):
		var size := Rooms.dimensions(str(room.kind),int(room.rotation))
		for x in range(int(room.x)*2,(int(room.x)+size.x)*2):
			for y in range(int(room.y)*2,(int(room.y)+size.y)*2): result[Vector2i(x,y)]=true
	return result

static func _door_cells(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for room in value.get("layout",[]):
		var door := Rooms.door_cell(room)
		for x in range(door.x*2,door.x*2+2):
			for y in range(door.y*2,door.y*2+2):
				if x >= 0 and y >= 0 and x < DIMENSIONS.x and y < DIMENSIONS.y: result[Vector2i(x,y)]=true
	return result

static func _circulation(value: Dictionary) -> Dictionary:
	var result: Dictionary = _door_cells(value)
	var layout: Array = value.get("layout",[])
	var parents := Rooms._paths(Rooms._occupied(layout),Rooms.unlocked_top(int(value.get("wings",0))))
	for room in layout:
		var cell := Rooms.door_cell(room)
		if not parents.has(cell): continue
		while true:
			for x in range(cell.x*2,cell.x*2+2):
				for y in range(cell.y*2,cell.y*2+2):
					if x >= 0 and y >= 0 and x < DIMENSIONS.x and y < DIMENSIONS.y: result[Vector2i(x,y)]=true
			if parents[cell] == cell: break
			cell=parents[cell]
	# The lobby spine and public routines are authored in HotelWorld._cast,
	# _service_cast and react_cat. Reserve their swept body envelopes, not
	# only the cells under their center lines. Residents/maids use the spine.
	for segment in [
		[Vector2(0,-4.4),Vector2(0,5.5)],
		[Vector2(1.02,3.8),Vector2(4.0,3.8)],
		[Vector2(3.85,-1.12),Vector2(4.7,-0.8)],
		[Vector2(-2.5,1.77),Vector2(-2.5,1.77)],
		[Vector2(2.0,-3.4),Vector2(2.0,-3.4)],
		[Vector2(3.3,1.3),Vector2(3.3,1.3)],
		[Vector2(-0.85,3.2),Vector2(0.85,3.2)],
	]:
		var start: Vector2=segment[0]; var finish: Vector2=segment[1]
		_mark_rect(result,Rect2(start.min(finish),(finish-start).abs()).grow(ACTOR_CLEARANCE))
	return result

static func _cell_rect(cell: Vector2i) -> Rect2:
	var corner := local_to_world(Vector2(cell))
	return Rect2(Vector2(corner.x,corner.z),Vector2.ONE*CELL_SIZE)

static func _mark_rect(mask: Dictionary, bounds: Rect2) -> void:
	var first := world_to_local(Vector3(bounds.position.x,0,bounds.position.y))
	var last := world_to_local(Vector3(bounds.end.x,0,bounds.end.y))
	for y in range(maxi(0,floori(first.y)),mini(DIMENSIONS.y,ceili(last.y))):
		for x in range(maxi(0,floori(first.x)),mini(DIMENSIONS.x,ceili(last.x))):
			var cell := Vector2i(x,y)
			if _cell_rect(cell).intersects(bounds): mask[cell]=true

static func _fixed_mask() -> Dictionary:
	if not _fixed_cache.is_empty(): return _fixed_cache
	# Canonical world-space envelopes of permanent HotelWorld scenery. Reserve
	# upper-tier extensions too so upgrading a service never invalidates a save.
	for bounds in [
		Rect2(-5.5,-4.4,4.95,4.4), # Public lounge, shelves, couches and planters.
		Rect2(0.65,-3.73,3.9,1.0), # Dining counter and its overhang.
		Rect2(0.98,-1.99,3.24,0.68), # Three dining bowls.
		Rect2(1.00,0.725,1.30,1.15), Rect2(2.69,0.725,1.22,1.15), # Climbing platforms.
		Rect2(1.865,1.97,1.27,1.16), # Playhouse.
		Rect2(3.885,0.85,0.73,0.84), # Climbing steps.
		Rect2(3.435,2.985,0.23,0.23), # Floor toy.
		Rect2(-4.425,2.025,3.65,1.05), # Reception counter including overhang.
		Rect2(-4.71,0.34,1.62,0.18), # Reception sign assembly.
		Rect2(-5.7,-0.05,1.3,0.2), Rect2(-3.4,-0.05,1.3,0.2),
		Rect2(-1.1,-0.05,0.15,0.2), Rect2(1.75,-0.05,3.9,0.2), # Lobby dividers.
		Rect2(-1.045,-0.085,0.25,0.27), Rect2(1.625,-0.085,0.25,0.27), # Door posts.
	]: _mark_rect(_fixed_cache,bounds)
	# Service planters and upgrade lanterns at their largest footprints.
	for center in [Vector2(2.6,-2.1),Vector2(2.6,2.1),Vector2(-2.6,2.1)]:
		for offset in [Vector2(-1.87,1.3),Vector2(1.85,-1.45),Vector2(1.82,1.24),Vector2(-1.75,1.1)]:
			_mark_rect(_fixed_cache,Rect2(center+offset-Vector2.ONE*0.32,Vector2.ONE*0.64))
	return _fixed_cache

static func _fixed(cell: Vector2i) -> bool:
	return _fixed_mask().has(cell)

static func _reason(value: Dictionary, cell: Vector2i) -> String:
	return _reason_with(value,cell,_masks(value))

static func _masks(value: Dictionary) -> Dictionary:
	return {"rooms":_room_cells(value),"doors":_door_cells(value),"circulation":_circulation(value)}

static func _reason_with(value: Dictionary, cell: Vector2i, masks: Dictionary) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= DIMENSIONS.x or cell.y >= DIMENSIONS.y: return "outside"
	if _cell_rect(cell).end.y > FRONT_WALL_Z: return "outside"
	if cell.y < Rooms.unlocked_top(int(value.get("wings",0)))*2: return "locked"
	if masks.rooms.has(cell): return "room_overlap"
	if masks.doors.has(cell): return "door_blocked"
	if _fixed(cell): return "fixed_overlap"
	if masks.circulation.has(cell): return "circulation_blocked"
	return ""

static func _message(code: String) -> String:
	return {"outside":"Keep the whole object on the shared floor.","locked":"Restore this wing before decorating here.",
		"room_overlap":"A guest room is here.","door_blocked":"Keep every room entrance clear.",
		"fixed_overlap":"Hotel furniture is already here.","circulation_blocked":"Keep the lobby route clear.",
		"overlap":"Another object is here.","room_full":"This shared space is full.",
		"unreachable_object":"Guests cannot reach this object."}.get(code,"Choose a valid shared-floor position.")

static func _result(ok: bool, code: String = "", blocked: Array = []) -> Dictionary:
	return {"ok":ok,"code":code,"message":"Ready to apply." if ok else _message(code),"blocked":blocked,"paths":{},"housekeeping":Vector2i(-1,-1)}

static func validate(value: Dictionary, instances: Array, require_bed: bool = false) -> Dictionary:
	if value.get("kind") != "shared": return _result(false,"invalid_room")
	if instances.size() > CAP: return _result(false,"room_full")
	var floor_cells: Dictionary = {}; var rug_cells: Dictionary = {}; var definitions: Dictionary = {}; var masks:=_masks(value)
	for raw in instances:
		if not raw is Dictionary: return _result(false,"invalid_item")
		var definition := Catalog.item(str(raw.get("item",""))); var uid := str(raw.get("uid",""))
		if definition.is_empty() or uid.is_empty() or definitions.has(uid): return _result(false,"invalid_item")
		for key in ["x","y","rotation"]:
			var number: Variant=raw.get(key)
			if not (number is int or number is float) or not is_finite(float(number)) or float(number)!=floor(float(number)): return _result(false,"invalid_item")
		if int(raw.rotation)<0 or int(raw.rotation)>3: return _result(false,"invalid_item")
		definitions[uid]=definition
		var cells := _footprint(raw,definition)
		for cell in cells:
			var reason := _reason_with(value,cell,masks)
			if not reason.is_empty(): return _result(false,reason,cells)
			var occupied: Dictionary = rug_cells if definition.layer == "rug" else floor_cells
			if occupied.has(cell): return _result(false,"overlap",[cell])
			occupied[cell]=uid
	# Interactive shared objects must remain connected to the permanent lobby spine.
	var parents: Dictionary = {}; var queue: Array[Vector2i] = []
	for cell in masks.circulation: parents[cell]=cell; queue.append(cell)
	var cursor := 0
	while cursor < queue.size():
		var cell: Vector2i=queue[cursor]; cursor+=1
		for step in STEPS:
			var neighbor:=cell+step
			if parents.has(neighbor) or floor_cells.has(neighbor) or not _reason_with(value,neighbor,masks).is_empty(): continue
			parents[neighbor]=cell; queue.append(neighbor)
	for raw in instances:
		var definition: Dictionary=definitions[str(raw.uid)]
		if not definition.interactive: continue
		var reachable := false
		for approach in definition.approaches:
			var cell:=Vector2i(int(raw.x),int(raw.y))+_rotate(approach,definition.footprint,int(raw.rotation))
			if parents.has(cell): reachable=true; break
		if not reachable: return _result(false,"unreachable_object")
	return _result(true)
