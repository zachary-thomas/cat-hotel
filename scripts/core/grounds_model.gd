extends RefCounted
## Saved neighborhood simulation. Rewards and work completion never depend on animation.
const Layout = preload("res://scripts/core/room_layout.gd")
const Interior = preload("res://scripts/core/furniture_layout.gd")
const Shared = preload("res://scripts/core/shared_layout.gd")
const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const AMENITIES = [
	{"id":"pool", "name":"Kitty splash pool", "cost":250, "level":1, "rate":5, "position":Vector2(9.3,-1.0), "copy":"A shallow splash pool with floating toys. Guests paddle and lounge by the water."},
	{"id":"litter", "name":"Private litter nook", "cost":120, "level":1, "rate":3, "position":Vector2(-9.2,-2.4), "copy":"Fresh litter, privacy screens and a little paw-washing mat."},
	{"id":"playpen", "name":"Rainbow playpen", "cost":350, "level":2, "rate":7, "position":Vector2(-9.1,1.8), "copy":"A fenced play garden with a tunnel, yarn and a climbing step."},
	{"id":"picnic", "name":"Catnip picnic garden", "cost":450, "level":2, "rate":9, "position":Vector2(9.2,-6.4), "copy":"A shady picnic table, flowers and catnip for a sociable afternoon."}
]
const YARN_SPOTS = [Vector2(-4.4,5.8),Vector2(5.4,6.2),Vector2(7.0,-8.5)]
const BUSH_SPOTS = [Vector2(-9.4,5.1),Vector2(10.0,3.6)]
const MOUSE_SPOT = Vector2(3.5,7.5)
const SHOP_SPOT = Vector2(-6.2,7.6)
const MANAGER_HOME = Vector2(0,6.0)
const SPEED = 3.5
const MAID_LEVEL = 3
const MAID_COST = 600
var seconds: float = 0
var hotels: Array = []
var notices: Array = []

func _init() -> void:
	reset()

func reset() -> void:
	seconds = 0
	hotels.clear()
	notices.clear()
	for h in range(4):
		hotels.append({"amenities":[], "yarn_ready":[0.0,0.0,0.0], "bush_ready":[0.0,25.0], "mouse_ready":0.0, "manager":[0.0,6.0], "job":{}, "dirty":[false,false,false,false,false,false,false,false], "dirt_clock":0.0, "dirt_cursor":0, "maid":false, "maid_position":[0.0,3.5], "maid_job":{}, "cleaned":0, "chores":0, "treat_ready":0.0, "treat_until":0.0})

static func amenity(id: String) -> Dictionary:
	for item in AMENITIES:
		if item.id == id:
			return item
	return {}

func bonus_rate(hotel: int) -> int:
	var total: int = 0
	for id in hotels[hotel].amenities:
		total += amenity(id).rate
	return total

static func room_spot(room: int, model = null, hotel: int = 0) -> Vector2:
	if model != null:
		var rooms: Array = Layout.entries(model,hotel)
		if room >= 0 and room < rooms.size():
			var p: Vector3 = Interior.housekeeping_world(rooms[room],model.furniture.room_items(hotel,room))
			if p == Vector3.ZERO: p = Layout.center(rooms[room])
			return Vector2(p.x,p.z)
	if room < 2:
		return Vector2(-3.9+room*2.3,-1.0)
	return Vector2(-2.9 if room%2 == 0 else 2.9, -5.75-int((room-2)/2)*4.2)

func dirty_rooms(hotel: int, count: int) -> Array:
	var result: Array = []
	for room in range(count):
		if hotels[hotel].dirty[room]:
			result.append(room)
	return result

func perform(model, action: String, payload: Dictionary) -> Dictionary:
	var h: int = model.current_hotel
	if not model.started or h < 0 or h >= hotels.size() or not model.hotels[h].owned:
		return fail("Open your hotel first.")
	var data: Dictionary = hotels[h]
	var index: int = int(payload.get("index",-1))
	match action:
		"yarn":
			if index < 0 or index >= YARN_SPOTS.size() or seconds < data.yarn_ready[index]:
				return fail("More yarn will appear soon.")
			data.yarn_ready[index] = seconds + 35
			model.coins_units += 5 * model.UNIT
			return ok("Found 5 Cat Coins in the yarn!", "collect")
		"amenity":
			var item: Dictionary = amenity(str(payload.get("id","")))
			if item.is_empty() or data.amenities.has(item.id):
				return fail("This amenity is already open.")
			if model.hotel_level(h) < item.level or model.coins < item.cost:
				return fail("This needs hotel level %d and %d Cat Coins." % [item.level,item.cost])
			model.coins_units -= item.cost * model.UNIT
			data.amenities.append(item.id)
			return ok(item.name + " is open for your guests!", "build")
		"hire_maid":
			if data.maid:
				return fail("Your maid is already on duty.")
			if model.hotel_level(h) < MAID_LEVEL or model.coins < MAID_COST:
				return fail("Hire a maid at hotel level 3 for 600 Cat Coins.")
			model.coins_units -= MAID_COST * model.UNIT
			data.maid = true
			_assign_maid(data,model.room_count(h),model,h)
			return ok("Daisy is on duty. She'll clean rooms automatically.", "open")
		"treats":
			if seconds < data.treat_ready or model.coins < 30:
				return fail("A treat picnic costs 30 coins and is available every two minutes.")
			model.coins_units -= 30 * model.UNIT
			data.treat_ready = seconds + 120
			data.treat_until = seconds + 25
			model.life.bond(model.life.state.favorite, 3, h)
			return ok("Treat picnic! Passing cats are coming over. +3 friendship.", "toy")
		"trim", "chase", "clean", "walk":
			if not data.job.is_empty():
				return fail("Your manager is finishing a job. Tap the manager to see progress.")
			var target: Vector2
			var work: float = 0
			if action == "trim":
				if index < 0 or index >= BUSH_SPOTS.size() or seconds < data.bush_ready[index]:
					return fail("That bush is already tidy.")
				target = BUSH_SPOTS[index]
				work = 4
			elif action == "chase":
				if seconds < data.mouse_ready:
					return fail("The mouse has already scampered away.")
				target = MOUSE_SPOT
				work = 3
			elif action == "clean":
				if index < 0 or index >= model.room_count(h) or not data.dirty[index]:
					return fail("That room is already clean.")
				if not data.maid_job.is_empty() and int(data.maid_job.room) == index:
					return fail("Daisy is already cleaning that room.")
				target = room_spot(index,model,h)
				work = 5
			else:
				target = Vector2(float(payload.get("x",0)),float(payload.get("z",6)))
				if not target.is_finite() or not walkable(target,model.wing_count(h),model,h):
					return fail("Tap a garden path, the front pavement or the hotel aisle.")
			var start = Vector2(data.manager[0],data.manager[1])
			data.job = make_job(action,index,start,target,work,model,h)
			if data.job.is_empty():
				return fail("The room entrance needs a clear path from the lobby.")
			return ok({"trim":"On my way to trim the bush.","chase":"Let's guide that little mouse out of the garden.","clean":"On my way to tidy the room.","walk":"On my way!"}[action], "tap")
	return fail("Choose an amenity or a manager job.")

static func walkable(p: Vector2, wings: int = 0, model = null, hotel: int = 0) -> bool:
	if model != null and _in_layout(p):
		return not _layout_path(model,hotel,p).is_empty()
	if not p.is_finite() or absf(p.x) > 11.8 or p.y > 11.0 or p.y < -17.5-clampi(wings,0,3)*2.5:
		return false
	if p.y < -17.5:
		return wings > 0
	return p.y >= 5.5 or absf(p.x) >= 6.3 or (absf(p.x) <= 0.7 and p.y >= -4.45-wings*4.2)

static func _in_layout(point: Vector2) -> bool:
	return point.y < -4.4 and point.y >= -17.6 and absf(point.x) < 5.5

static func _layout_path(model, hotel: int, point: Vector2) -> Array:
	var rooms: Array = Layout.entries(model,hotel)
	var grid: Vector2 = (point-Layout.ORIGIN)/Layout.CELL_SIZE
	for room in range(rooms.size()):
		var entry: Dictionary = rooms[room]
		var size: Vector2i = Layout.dimensions(entry.kind,int(entry.rotation))
		if Rect2(Vector2(entry.x,entry.y),Vector2(size)).has_point(grid):
			var path: Array = Layout.route_to_door(model,hotel,room)
			var inside: Array[Vector3] = Interior.route_to_housekeeping(entry,model.furniture.room_items(hotel,room))
			for p in inside: path.append(Vector2(p.x,p.z))
			if not path.is_empty() and not path[-1].is_equal_approx(point): path.append(point)
			return path
	return _shared_aisle_path(model,hotel,point)

static func _shared_aisle_path(model, hotel: int, point: Vector2) -> Array:
	var shared := Shared.data(model.hotels,hotel)
	var local := Shared.world_to_local(Vector3(point.x,0.24,point.y))
	var target := Vector2i(floori(local.x),floori(local.y))
	var masks: Dictionary = Shared._masks(shared); var obstacles: Array[Rect2] = []
	for instance in model.furniture.room_items(hotel,-2):
		var definition := Catalog.item(str(instance.item))
		if definition.get("layer","") == "floor":
			var cells: Array[Vector2i] = Shared._footprint(instance,definition)
			if not cells.is_empty():
				var bounds: Rect2 = Shared._cell_rect(cells[0])
				for index in range(1,cells.size()): bounds = bounds.merge(Shared._cell_rect(cells[index]))
				obstacles.append(bounds.grow(Shared.ACTOR_CLEARANCE))
	if _shared_blocked_point(point,obstacles) or not _shared_walk_cell(shared,target,masks): return []
	var parents: Dictionary = {}; var queue: Array[Vector2i] = []
	var lobby_local := Shared.world_to_local(Vector3(0,0,-4.4)); var lobby := Vector2i(floori(lobby_local.x),floori(lobby_local.y))
	if _shared_blocked_cell(lobby,obstacles) or not _shared_walk_cell(shared,lobby,masks): return []
	parents[lobby]=lobby; queue.append(lobby)
	var cursor := 0
	while cursor < queue.size() and not parents.has(target):
		var cell: Vector2i = queue[cursor]; cursor += 1
		for step in Shared.STEPS:
			var neighbor: Vector2i = cell + step
			if parents.has(neighbor) or _shared_blocked_cell(neighbor,obstacles) or not _shared_walk_cell(shared,neighbor,masks): continue
			if not _shared_segment_clear(_shared_cell_center(cell),_shared_cell_center(neighbor),obstacles): continue
			parents[neighbor]=cell; queue.append(neighbor)
	if not parents.has(target): return []
	var result: Array = []
	var cell := target
	while true:
		var world := Shared.local_to_world(Vector2(cell)+Vector2(0.5,0.5)); result.push_front(Vector2(world.x,world.z))
		if parents[cell] == cell: break
		cell=parents[cell]
	if not result[-1].is_equal_approx(point):
		if not _shared_segment_clear(result[-1],point,obstacles): return []
		result.append(point)
	return result

static func _shared_cell_center(cell: Vector2i) -> Vector2:
	var world := Shared.local_to_world(Vector2(cell)+Vector2(0.5,0.5))
	return Vector2(world.x,world.z)

static func _shared_blocked_cell(cell: Vector2i, obstacles: Array[Rect2]) -> bool:
	return _shared_blocked_point(_shared_cell_center(cell),obstacles)

static func _shared_blocked_point(point: Vector2, obstacles: Array[Rect2]) -> bool:
	for bounds in obstacles:
		if bounds.has_point(point): return true
	return false

static func _shared_segment_clear(start: Vector2, finish: Vector2, obstacles: Array[Rect2]) -> bool:
	for bounds in obstacles:
		if _segment_intersects_rect(start,finish,bounds): return false
	return true

static func _segment_intersects_rect(start: Vector2, finish: Vector2, bounds: Rect2) -> bool:
	if bounds.has_point(start) or bounds.has_point(finish): return true
	var a := bounds.position; var b := Vector2(bounds.end.x,bounds.position.y)
	var c := bounds.end; var d := Vector2(bounds.position.x,bounds.end.y)
	for edge in [[a,b],[b,c],[c,d],[d,a]]:
		if Geometry2D.segment_intersects_segment(start,finish,edge[0],edge[1]) != null: return true
	return false

static func _shared_walk_cell(shared: Dictionary, cell: Vector2i, masks: Dictionary) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= Shared.DIMENSIONS.x or cell.y >= Shared.DIMENSIONS.y: return false
	if Shared._cell_rect(cell).end.y > Shared.FRONT_WALL_Z or cell.y < Layout.unlocked_top(int(shared.wings))*2: return false
	return not masks.rooms.has(cell) and not Shared._fixed(cell)

static func _to_front(point: Vector2, model = null, hotel: int = 0) -> Array:
	if model != null and _in_layout(point):
		var inside: Array = _layout_path(model,hotel,point)
		if inside.is_empty():
			return []
		inside.reverse()
		inside.append(Vector2(0,inside[-1].y))
		inside.append(Vector2(0,5.8))
		return inside
	var points: Array = [point]
	if point.y < 5.6:
		if point.y < -17.4:
			var lane: float = -6.6 if point.x < 0 else 6.6
			points.append(Vector2(lane,point.y))
			points.append(Vector2(lane,5.8))
		elif absf(point.x) >= 6.3:
			points.append(Vector2(6.6*signf(point.x),point.y))
			points.append(Vector2(6.6*signf(point.x),5.8))
		elif point.y < -4.6 and absf(point.x) > 0.8:
			var entry_z: float = -5.75-clampi(int((-point.y-4.6)/4.2),0,2)*4.2
			points.append(Vector2(point.x,entry_z))
			points.append(Vector2(0,entry_z))
			points.append(Vector2(0,5.8))
		elif point.x < -0.8 and point.y < -0.2:
			var door_x: float = -3.9 if point.x < -2.65 else -1.6
			points.append(Vector2(door_x,point.y))
			points.append(Vector2(door_x,0.65))
			points.append(Vector2(0,0.65))
			points.append(Vector2(0,5.8))
		else:
			points.append(Vector2(0,point.y))
			points.append(Vector2(0,5.8))
	else:
		points.append(Vector2(point.x,5.8))
	return points

static func route(start: Vector2, target: Vector2, model = null, hotel: int = 0) -> Array:
	# Shared by visitors, the manager and housekeeping: use actual door openings.
	var points: Array = _to_front(start,model,hotel)
	var arrival: Array = _to_front(target,model,hotel)
	if points.is_empty() or arrival.is_empty():
		return []
	arrival.reverse()
	points.append_array(arrival)
	return points

static func make_job(kind: String, index: int, start: Vector2, target: Vector2, work: float, model = null, hotel: int = 0) -> Dictionary:
	var path: Array = route(start,target,model,hotel)
	if path.is_empty():
		return {}
	var distance: float = 0
	var packed: Array = []
	for i in range(path.size()):
		packed.append([path[i].x,path[i].y])
		if i > 0:
			distance += path[i-1].distance_to(path[i])
	return {"kind":kind,"index":index,"path":packed,"elapsed":0.0,"travel":distance/SPEED,"work":work,"duration":distance/SPEED+work}

static func job_position(job: Dictionary) -> Vector2:
	var distance: float = float(job.elapsed) * SPEED
	for i in range(1,job.path.size()):
		var a = Vector2(job.path[i-1][0],job.path[i-1][1])
		var b = Vector2(job.path[i][0],job.path[i][1])
		var length: float = a.distance_to(b)
		if distance <= length and length > 0:
			return a.lerp(b,distance/length)
		distance -= length
	return Vector2(job.path[-1][0],job.path[-1][1])

func advance(delta: float, model) -> void:
	if delta <= 0 or not is_finite(delta):
		return
	seconds += delta
	for h in range(hotels.size()):
		if not model.hotels[h].owned:
			continue
		var data: Dictionary = hotels[h]
		var count: int = model.room_count(h)
		if not data.job.is_empty():
			data.job.elapsed += delta
			var p: Vector2 = job_position(data.job)
			data.manager = [p.x,p.y]
			if data.job.elapsed >= data.job.duration:
				var reward: int = 0
				match data.job.kind:
					"trim":
						data.bush_ready[int(data.job.index)] = seconds + 90
						reward = 15
					"chase":
						data.mouse_ready = seconds + 75
						reward = 12
					"clean":
						data.dirty[int(data.job.index)] = false
						data.cleaned += 1
						reward = 10
				if reward > 0:
					data.chores += 1
					model.coins_units += reward * model.UNIT
					notices.append({"hotel":h,"message":"Job done! +%d Cat Coins" % reward})
				data.job = {}
		data.dirt_clock += delta
		# Bounded offline catch-up: no flood of tasks or unattended reward farming.
		var dirt_count: int = mini(count,int(data.dirt_clock/65))
		data.dirt_clock = fmod(data.dirt_clock,65)
		for i in range(dirt_count):
			var room: int = int(data.dirt_cursor) % count
			data.dirty[room] = true
			data.dirt_cursor = (room+1)%count
		if not data.maid_job.is_empty():
			data.maid_job.elapsed += delta
			var mp: Vector2 = job_position(data.maid_job)
			data.maid_position = [mp.x,mp.y]
			if data.maid_job.elapsed >= data.maid_job.duration:
				data.dirty[int(data.maid_job.room)] = false
				data.cleaned += 1
				data.maid_job = {}
		if data.maid and delta >= 120:
			# Summarize a long absence: the housekeeper leaves open rooms tidy.
			for room in range(count):
				if data.dirty[room]:
					data.cleaned += 1
					data.dirty[room] = false
			data.maid_job = {}
		elif data.maid:
			_assign_maid(data,count,model,h)
	if notices.size() > 8:
		notices = notices.slice(-8)

func _assign_maid(data: Dictionary, count: int, model = null, hotel: int = 0) -> void:
	if not data.maid_job.is_empty():
		return
	for room in range(count):
		if data.dirty[room] and (data.job.is_empty() or data.job.kind != "clean" or int(data.job.index) != room):
			data.maid_job = make_job("clean",room,Vector2(data.maid_position[0],data.maid_position[1]),room_spot(room,model,hotel),6,model,hotel)
			if data.maid_job.is_empty():
				continue
			data.maid_job.room = room
			return

func layout_changed(model, hotel: int) -> void:
	# Replan inside the same saved transaction as the room move. Never award stale work.
	var data: Dictionary = hotels[hotel]
	var previous: Dictionary = data.job.duplicate(true)
	var manager_point := Vector2(data.manager[0],data.manager[1])
	var maid_point := Vector2(data.maid_position[0],data.maid_position[1])
	if _in_layout(manager_point) or (previous.get("kind","") == "clean"):
		data.manager = [0.0,3.5]
	if _in_layout(maid_point) or not data.maid_job.is_empty():
		data.maid_position = [0.0,3.5]
	data.job = {}
	data.maid_job = {}
	if not previous.is_empty():
		var index: int = int(previous.index)
		var target := Vector2(previous.path[-1][0],previous.path[-1][1])
		var resume: bool = true
		if previous.kind == "clean":
			resume = index >= 0 and index < model.room_count(hotel) and data.dirty[index]
			if resume:
				target = room_spot(index,model,hotel)
		elif previous.kind == "walk":
			resume = walkable(target,model.wing_count(hotel),model,hotel)
		if resume:
			data.job = make_job(previous.kind,index,Vector2(data.manager[0],data.manager[1]),target,float(previous.work),model,hotel)
	if data.maid:
		_assign_maid(data,model.room_count(hotel),model,hotel)

static func ok(message: String, sound: String = "tap") -> Dictionary:
	return {"ok":true,"message":message,"sound":sound}

static func fail(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func serialize() -> Dictionary:
	return {"seconds":seconds,"hotels":hotels.duplicate(true)}

static func number(value: Variant, minimum: float = 0, maximum: float = 1e12) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func valid_job(job: Variant, maid: bool = false) -> bool:
	if not job is Dictionary:
		return false
	if job.is_empty():
		return true
	if not job.get("kind") in ["walk","trim","chase","clean"] or not number(job.get("index"),-1,7):
		return false
	if float(job.index) != floor(float(job.index)):
		return false
	if job.kind == "trim" and not int(job.index) in [0,1]:
		return false
	if job.kind == "clean" and int(job.index) < 0:
		return false
	for key in ["elapsed","travel","work","duration"]:
		if not number(job.get(key),0,300):
			return false
	if job.elapsed > job.duration or not is_equal_approx(float(job.duration),float(job.travel)+float(job.work)):
		return false
	if not job.get("path") is Array or job.path.size() < 2 or job.path.size() > 256:
		return false
	for point in job.path:
		if not point is Array or point.size() != 2 or not number(point[0],-14,14) or not number(point[1],-25.5,12):
			return false
	if maid and (job.kind != "clean" or job.get("room",-1) != job.index):
		return false
	return true

func restore(saved: Variant) -> bool:
	if saved == null:
		reset()
		return true
	if not saved is Dictionary or not number(saved.get("seconds")) or not saved.get("hotels") is Array or saved.hotels.size() != 4:
		return false
	for data in saved.hotels:
		if not data is Dictionary or not data.get("amenities") is Array or data.amenities.size() > 4:
			return false
		var seen: Array = []
		for id in data.amenities:
			if not id is String or amenity(id).is_empty() or seen.has(id):
				return false
			seen.append(id)
		for key in ["mouse_ready","dirt_clock","dirt_cursor","cleaned","chores","treat_ready","treat_until"]:
			if not number(data.get(key)):
				return false
		if not data.get("maid") is bool or not valid_job(data.get("job")) or not valid_job(data.get("maid_job"),true):
			return false
		if not data.get("dirty") is Array or data.dirty.size() != 8:
			return false
		for dirty in data.dirty:
			if not dirty is bool:
				return false
		for pair in [["yarn_ready",3],["bush_ready",2]]:
			if not data.get(pair[0]) is Array or data[pair[0]].size() != pair[1]:
				return false
			for value in data[pair[0]]:
				if not number(value):
					return false
		if not data.get("maid_position") is Array or data.maid_position.size() != 2 or not number(data.maid_position[0],-14,14) or not number(data.maid_position[1],-25.5,12):
			return false
		if not data.get("manager") is Array or data.manager.size() != 2 or not number(data.manager[0],-14,14) or not number(data.manager[1],-25.5,12):
			return false
	seconds = float(saved.seconds)
	hotels = saved.hotels.duplicate(true)
	notices.clear()
	return true
