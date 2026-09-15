extends RefCounted
## World coordinates shared by land ownership, placement, scenery and walking.
const CAMERA_BOUNDS = Rect2(-38,-45,76,73)
const PLOTS = [
	{"id":"west","name":"West garden","cost":750,"rect":Rect2(-30,-38,12,43.5)},
	{"id":"east","name":"East garden","cost":750,"rect":Rect2(18,-38,12,43.5)},
	{"id":"north","name":"Rear garden","cost":1000,"rect":Rect2(-18,-38,36,12)}
]
const FOOTPRINT = Vector2(4.4,3.5)
const CLEARANCE = 0.2
const FIXTURES = [Rect2(-11.0,-12.5,4.0,7.5),Rect2(-10.6,4.1,2.4,2.0),Rect2(8.8,2.6,2.4,2.0),
	Rect2(-18.1,-9.8,0.8,1.6),Rect2(-18.1,-5.6,0.8,1.6),Rect2(-18.1,3.7,0.8,1.6),
	Rect2(17.3,-9.8,0.8,1.6),Rect2(17.3,-5.6,0.8,1.6),Rect2(17.3,3.7,0.8,1.6)]
const STEPS = [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]

static func plot(id: String) -> Dictionary:
	for item in PLOTS:
		if item.id == id: return item
	return {}

static func position(data: Dictionary, item: Dictionary) -> Vector2:
	var saved: Dictionary = data.get("amenity_layout",{}).get(item.id,{})
	return Vector2(saved.x,saved.z) if not saved.is_empty() else item.position

static func rotation(data: Dictionary, id: String) -> int:
	return int(data.get("amenity_layout",{}).get(id,{}).get("rotation",0))

static func footprint(point: Vector2, turn: int) -> Rect2:
	var size := FOOTPRINT if turn % 2 == 0 else Vector2(FOOTPRINT.y,FOOTPRINT.x)
	return Rect2(point-size*0.5,size)

static func owned(point: Vector2, data: Dictionary, wings: int) -> bool:
	# Side gardens are open from the start; the old rear strips still follow repairs.
	if absf(point.x) <= 18 and point.y >= -26 and point.y <= 5.5:
		if absf(point.x) >= 7.0 or point.y >= -17.5: return true
		if point.y >= -17.5-clampi(wings,0,3)*2.5: return true
	for id in data.get("plots",[]):
		if plot(id).rect.has_point(point): return true
	return false

static func validate(data: Dictionary, items: Array, id: String, point: Vector2, turn: int, wings: int) -> Dictionary:
	if not point.is_finite() or turn < 0 or turn > 3:
		return {"ok":false,"message":"Choose a spot on the garden."}
	var bounds := footprint(point,turn)
	# Sample the entire footprint so a plot seam cannot bridge locked land.
	for x in range(ceil(bounds.size.x/0.4)+1):
		for z in range(ceil(bounds.size.y/0.4)+1):
			var p := bounds.position+Vector2(minf(x*0.4,bounds.size.x),minf(z*0.4,bounds.size.y))
			if not owned(p,data,wings): return {"ok":false,"message":"Keep the whole amenity on open land. Open a garden plot to grow."}
	if bounds.intersects(Rect2(-7.0,-18.0,14.0,23.5)) or bounds.intersects(Rect2(-1.3,-38,2.6,20)):
		return {"ok":false,"message":"Keep the hotel and its walking paths clear."}
	for fixed in FIXTURES:
		if bounds.grow(CLEARANCE).intersects(fixed): return {"ok":false,"message":"Leave space around the orchard and bushes."}
	for item in items:
		if item.id != id and bounds.grow(CLEARANCE).intersects(footprint(position(data,item),rotation(data,item.id))):
			return {"ok":false,"message":"Leave a little space between amenities."}
	return {"ok":true,"message":"Ready to move · Free"}

static func valid_saved(data: Dictionary, items: Array) -> bool:
	if not data.get("plots",[]) is Array or data.get("plots",[]).size()>3: return false
	var seen := {}
	for id in data.get("plots",[]):
		if not id is String or plot(id).is_empty() or seen.has(id): return false
		seen[id]=true
	if not data.get("amenity_layout",{}) is Dictionary or data.get("amenity_layout",{}).size()>4: return false
	for id in data.get("amenity_layout",{}):
		if not data.amenities.has(id): return false
		var saved = data.amenity_layout[id]
		if not saved is Dictionary: return false
		for key in ["x","z","rotation"]:
			if not (saved.get(key) is int or saved.get(key) is float) or not is_finite(float(saved[key])): return false
		if float(saved.rotation) != floor(float(saved.rotation)): return false
		if not validate(data,items,id,Vector2(saved.x,saved.z),int(saved.rotation),3).ok: return false
	return true

static func outdoor_walkable(p: Vector2, data: Dictionary, items: Array, wings: int) -> bool:
	if not p.is_finite(): return false
	if p.y >= 5.5 and p.y <= 12 and absf(p.x) <= 32:
		return not Rect2(-8.3,6.3,4.2,2.5).has_point(p) # Paw Mart
	if not owned(p,data,wings) or (absf(p.x)<6.15 and p.y>-17.8): return false
	for fixed in FIXTURES:
		if fixed.grow(0.35).has_point(p): return false
	for item in items:
		if footprint(position(data,item),rotation(data,item.id)).grow(0.4).has_point(p): return false
	return true

static func outdoor_route(point: Vector2, data: Dictionary, items: Array, wings: int) -> Array:
	# Routes join the hotel's front entrance, without cutting across moved amenities.
	var origin := Vector2i(0,6)
	if not outdoor_walkable(point,data,items,wings): return []
	var destinations := {}
	for x in [floori(point.x),ceili(point.x)]:
		for z in [floori(point.y),ceili(point.y)]:
			var cell := Vector2i(x,z)
			if _outdoor_segment_clear(Vector2(cell),point,data,items,wings): destinations[cell]=true
	if destinations.is_empty(): return []
	var parents := {origin:origin}
	var queue: Array[Vector2i] = [origin]
	var cursor := 0
	var destination := origin
	var found := false
	while cursor < queue.size():
		var cell := queue[cursor]; cursor += 1
		if destinations.has(cell): destination=cell; found=true; break
		for step in STEPS:
			var neighbor: Vector2i = cell+step
			if parents.has(neighbor) or not outdoor_walkable(Vector2(neighbor),data,items,wings): continue
			if not outdoor_walkable((Vector2(cell)+Vector2(neighbor))*0.5,data,items,wings): continue
			parents[neighbor]=cell; queue.append(neighbor)
	if not found: return []
	var result: Array = [point]
	var cell := destination
	while cell != origin:
		result.append(Vector2(cell)); cell=parents[cell]
	result.append(Vector2(origin)); result.append(Vector2(0,5.8))
	return result

static func _outdoor_segment_clear(a: Vector2, b: Vector2, data: Dictionary, items: Array, wings: int) -> bool:
	for step in range(9):
		if not outdoor_walkable(a.lerp(b,step/8.0),data,items,wings): return false
	return true
