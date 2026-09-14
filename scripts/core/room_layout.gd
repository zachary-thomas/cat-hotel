extends RefCounted
## Pure grid rules. Room indices also identify saved furnishings and housekeeping.
const GRID_WIDTH: int = 10
const GRID_HEIGHT: int = 12
const CELL_SIZE: float = 1.1
const ORIGIN = Vector2(-5.5, -17.6)
const MAX_ROOMS: int = 8
const REGULAR_COST: int = 450
const SUITE_COST: int = 1200
const STEPS = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]

static func migrate(hotel: Dictionary) -> Array:
	if not hotel.has("layout"):
		var rooms: Array = []
		for index in range(2 + int(hotel.get("wings", 0)) * 2):
			rooms.append({"kind":"regular", "x":0 if index % 2 == 0 else 6,
				"y":9 - int(index / 2) * 3, "rotation":0 if index % 2 == 0 else 2})
		hotel["layout"] = rooms
	for room in hotel.layout:
		for key in ["x", "y", "rotation"]:
			room[key] = int(room[key])
	return hotel.layout

static func entries(model, hotel: int) -> Array:
	if hotel < 0 or hotel >= model.hotels.size():
		return []
	return migrate(model.hotels[hotel])

static func dimensions(kind: String, rotation: int = 0) -> Vector2i:
	var size := Vector2i(4, 5 if kind == "suite" else 3)
	return Vector2i(size.y, size.x) if rotation % 2 else size

static func center(room: Dictionary) -> Vector3:
	var size: Vector2i = dimensions(room.kind, int(room.rotation))
	return Vector3(ORIGIN.x + (float(room.x) + size.x * 0.5) * CELL_SIZE, 0.24,
		ORIGIN.y + (float(room.y) + size.y * 0.5) * CELL_SIZE)

## Rotation 0 faces east, then south, west and north, clockwise.
static func door_cell(room: Dictionary) -> Vector2i:
	var size: Vector2i = dimensions(room.kind, int(room.rotation))
	var origin := Vector2i(int(room.x), int(room.y))
	match int(room.rotation):
		0: return origin + Vector2i(size.x, int(size.y / 2))
		1: return origin + Vector2i(int(size.x / 2), size.y)
		2: return origin + Vector2i(-1, int(size.y / 2))
		_: return origin + Vector2i(int(size.x / 2), -1)

static func cost(kind: String) -> int:
	return SUITE_COST if kind == "suite" else REGULAR_COST

static func income(kind: String) -> int:
	return 28 if kind == "suite" else 12

static func unlocked_top(wings: int) -> int:
	return GRID_HEIGHT - 3 * (wings + 1)

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func _shape(room: Variant) -> bool:
	if not room is Dictionary or not room.get("kind") is String or room.kind not in ["regular", "suite"]:
		return false
	for key in ["x", "y", "rotation"]:
		if not _whole(room.get(key)):
			return false
	return float(room.rotation) >= 0 and float(room.rotation) <= 3 and absf(float(room.x)) <= 1000 and absf(float(room.y)) <= 1000

static func _occupied(layout: Array) -> Dictionary:
	var occupied: Dictionary = {}
	for room in layout:
		var size: Vector2i = dimensions(room.kind, int(room.rotation))
		for x in range(int(room.x), int(room.x) + size.x):
			for y in range(int(room.y), int(room.y) + size.y):
				occupied[Vector2i(x, y)] = true
	return occupied

## Parent links form shortest paths from the lobby boundary through open cells.
static func _paths(occupied: Dictionary, top: int) -> Dictionary:
	var parents: Dictionary = {}
	var queue: Array[Vector2i] = []
	for x in range(GRID_WIDTH):
		var outside := Vector2i(x, GRID_HEIGHT)
		parents[outside] = outside
		var cell := Vector2i(x, GRID_HEIGHT - 1)
		if not occupied.has(cell):
			parents[cell] = outside
			queue.append(cell)
	var cursor: int = 0
	while cursor < queue.size():
		var cell: Vector2i = queue[cursor]
		cursor += 1
		for step in STEPS:
			var neighbor: Vector2i = cell + step
			if neighbor.x < 0 or neighbor.x >= GRID_WIDTH or neighbor.y < top or neighbor.y >= GRID_HEIGHT:
				continue
			if occupied.has(neighbor) or parents.has(neighbor):
				continue
			parents[neighbor] = cell
			queue.append(neighbor)
	return parents

static func _check(layout: Array, wings: int) -> Dictionary:
	if layout.size() > MAX_ROOMS:
		return {"ok":false, "message":"Your hotel can hold up to eight rooms."}
	var occupied: Dictionary = {}
	for room in layout:
		if not _shape(room):
			return {"ok":false, "message":"Choose a regular room or suite on the building grid."}
		var size: Vector2i = dimensions(room.kind, int(room.rotation))
		if int(room.x) < 0 or int(room.x) + size.x > GRID_WIDTH or int(room.y) < 0 or int(room.y) + size.y > GRID_HEIGHT:
			return {"ok":false, "message":"Keep the whole room inside the hotel floor."}
		if int(room.y) < unlocked_top(wings):
			return {"ok":false, "message":"Restore the next wing to build on this floor space."}
		for x in range(int(room.x), int(room.x) + size.x):
			for y in range(int(room.y), int(room.y) + size.y):
				var cell := Vector2i(x, y)
				if occupied.has(cell):
					return {"ok":false, "message":"This room overlaps another room."}
				occupied[cell] = true
	var parents: Dictionary = _paths(occupied, unlocked_top(wings))
	for room in layout:
		if not parents.has(door_cell(room)):
			return {"ok":false, "message":"Leave an open path from every entrance to the lobby."}
	return {"ok":true, "message":"Ready to build."}

static func valid_saved(layout: Variant, wings: int) -> bool:
	return wings >= 0 and wings <= 3 and layout is Array and layout.size() >= 2 and bool(_check(layout, wings).ok)

static func validate(model, hotel: int, candidate: Dictionary, moving: int = -1) -> Dictionary:
	if hotel < 0 or hotel >= model.hotels.size() or not model.hotels[hotel].owned:
		return {"ok":false, "message":"Choose an open hotel first."}
	var layout: Array = entries(model, hotel).duplicate(true)
	if moving < -1 or moving >= layout.size():
		return {"ok":false, "message":"Choose an existing room to move."}
	if moving >= 0:
		if candidate.get("kind") != layout[moving].kind:
			return {"ok":false, "message":"Moving keeps your existing room type."}
		layout[moving] = candidate
	else:
		layout.append(candidate)
	var result := _check(layout, model.wing_count(hotel))
	if not result.ok: return result
	var shared_items: Array = model.furniture.room_items(hotel,-2)
	if not shared_items.is_empty():
		var candidate_hotels: Array = model.hotels.duplicate(true)
		candidate_hotels[hotel].layout = layout
		var shared = load("res://scripts/core/shared_layout.gd")
		var placement: Dictionary = shared.validate(shared.data(candidate_hotels,hotel),shared_items,false)
		if not placement.ok: return {"ok":false,"message":"Move shared furniture clear of this room and its entrance first."}
	return result

static func perform(model, action: String, payload: Dictionary) -> Dictionary:
	if action not in ["place_room", "move_room"]:
		return {"ok":false, "message":"Choose a room building action.", "room":-1}
	var hotel_value: Variant = payload.get("hotel", model.current_hotel)
	var moving_value: Variant = payload.get("room", -1) if action == "move_room" else -1
	if not _whole(hotel_value) or not _whole(moving_value):
		return {"ok":false, "message":"Choose an open hotel and room.", "room":-1}
	var hotel: int = int(hotel_value)
	var moving: int = int(moving_value)
	if action == "move_room" and moving < 0:
		return {"ok":false, "message":"Choose an existing room to move.", "room":-1}
	var candidate: Dictionary = {}
	for key in ["kind", "x", "y", "rotation"]:
		candidate[key] = payload.get(key)
	var result: Dictionary = validate(model, hotel, candidate, moving)
	result["room"] = -1
	if not result.ok:
		return result
	var price: int = 0 if action == "move_room" else cost(candidate.kind)
	if model.coins_units < price * model.UNIT:
		return {"ok":false, "message":"You need %d coins to build this room." % price, "room":-1}
	for key in ["x", "y", "rotation"]:
		candidate[key] = int(candidate[key])
	var layout: Array = entries(model, hotel)
	var before_layout: Array = layout.duplicate(true)
	var before_furniture: Dictionary = model.furniture.serialize()
	var before_coins: int = model.coins_units
	var before_purchases: int = int(model.hotels[hotel].purchases)
	if moving >= 0:
		layout[moving] = candidate
	else:
		moving = layout.size()
		layout.append(candidate)
		model.coins_units -= price * model.UNIT
		model.hotels[hotel].purchases = int(model.hotels[hotel].purchases) + 1
	if not model.furniture.ensure_rooms(model,hotel):
		model.hotels[hotel].layout = before_layout
		model.furniture.state = before_furniture
		model.coins_units = before_coins
		model.hotels[hotel].purchases = before_purchases
		return {"ok":false,"message":"This room's furniture could not be initialized.","room":-1}
	if price > 0: model.life.sync_discoveries(model.discovered_cats())
	if price == 0:
		model.furniture.state.revision = int(model.furniture.state.revision) + 1
		for record in model.furniture.state.rooms:
			if int(record.hotel) == hotel and int(record.room) == moving:
				record.revision = int(record.revision) + 1
				break
	model.life.touch()
	return {"ok":true, "message":"Room moved." if action == "move_room" else "Your new room is ready!", "room":moving}

static func route(model, hotel: int, room: int) -> Array[Vector2]:
	var result := route_to_door(model,hotel,room)
	if result.is_empty(): return result
	var room_center: Vector3 = center(entries(model,hotel)[room])
	result.append(Vector2(room_center.x,room_center.z))
	return result

static func route_to_door(model, hotel: int, room: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var layout: Array = entries(model, hotel)
	if room < 0 or room >= layout.size():
		return result
	var parents: Dictionary = _paths(_occupied(layout), unlocked_top(model.wing_count(hotel)))
	var cell: Vector2i = door_cell(layout[room])
	if not parents.has(cell):
		return result
	while true:
		result.push_front(ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE)
		if parents[cell] == cell:
			break
		cell = parents[cell]
	var data: Dictionary = layout[room]
	var size: Vector2i = dimensions(data.kind,int(data.rotation))
	var c: Vector3 = center(data)
	match int(data.rotation):
		0: result.append(Vector2(c.x+size.x*CELL_SIZE*0.5,c.z))
		1: result.append(Vector2(c.x,c.z+size.y*CELL_SIZE*0.5))
		2: result.append(Vector2(c.x-size.x*CELL_SIZE*0.5,c.z))
		_: result.append(Vector2(c.x,c.z-size.y*CELL_SIZE*0.5))
	return result
