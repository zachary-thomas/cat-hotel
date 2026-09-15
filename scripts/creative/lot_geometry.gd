extends RefCounted
## Coordinates shared by saved construction, previews, renderers and walking.
const CELL := 1.1
const Content = preload("res://scripts/creative/creative_content.gd")

static func room_rect(room: Dictionary) -> Rect2:
	var size := Vector2(float(room.w),float(room.h))
	if int(room.get("rotation",0))%2: size=Vector2(size.y,size.x)
	return Rect2(Vector2(float(room.x),float(room.y)),size)

static func object_rect(object: Dictionary) -> Rect2:
	var definition: Dictionary=Content.item(str(object.item))
	var raw: Array=definition.get("size",[1,1])
	var size:=Vector2(float(raw[0]),float(raw[1]))
	if int(object.get("rotation",0))%2: size=Vector2(size.y,size.x)
	return Rect2(Vector2(float(object.x),float(object.y)),size)

static func door(room: Dictionary) -> Vector2:
	var rect:=room_rect(room)
	match int(room.get("rotation",0))%4:
		0: return Vector2(rect.end.x+0.25,rect.get_center().y)
		1: return Vector2(rect.get_center().x,rect.end.y+0.25)
		2: return Vector2(rect.position.x-0.25,rect.get_center().y)
		_: return Vector2(rect.get_center().x,rect.position.y-0.25)

static func rect(raw: Array) -> Rect2:
	return Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))

static func point_owned(point: Vector2, map: Dictionary, hotel: Dictionary) -> bool:
	if rect(map.base).has_point(point): return true
	for plot in map.plots:
		if hotel.plots.has(plot.id) and rect(plot.rect).has_point(point): return true
	return false

static func owns_rect(bounds: Rect2, map: Dictionary, hotel: Dictionary) -> bool:
	for x in range(floori(bounds.position.x*2),ceili(bounds.end.x*2)):
		for y in range(floori(bounds.position.y*2),ceili(bounds.end.y*2)):
			if not point_owned(Vector2(x*0.5+0.25,y*0.5+0.25),map,hotel): return false
	return true

static func room_for(object: Dictionary, rooms: Array) -> String:
	var footprint:=object_rect(object)
	for room in rooms:
		if room_rect(room).encloses(footprint): return str(room.id)
	return ""

static func room_by_id(rooms: Array, id: String) -> Dictionary:
	for room in rooms:
		if str(room.id)==id: return room
	return {}

static func portal(room: Dictionary, point: Vector2) -> bool:
	if str(room.kind)=="terrace": return true
	var r:=room_rect(room)
	var middle:=r.get_center()
	var side:=int(room.get("rotation",0))%4
	var all_sides:=str(room.kind)=="shared"
	if (all_sides or side==0) and absf(point.x-r.end.x)<0.3 and absf(point.y-middle.y)<0.8: return true
	if (all_sides or side==1) and absf(point.y-r.end.y)<0.3 and absf(point.x-middle.x)<0.8: return true
	if (all_sides or side==2) and absf(point.x-r.position.x)<0.3 and absf(point.y-middle.y)<0.8: return true
	if (all_sides or side==3) and absf(point.y-r.position.y)<0.3 and absf(point.x-middle.x)<0.8: return true
	return false

static func transform_point(point: Vector2, original: Rect2, destination: Rect2, turns: int) -> Vector2:
	var p:=point-original.get_center()
	for n in range(posmod(turns,4)): p=Vector2(-p.y,p.x)
	return destination.get_center()+p

static func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func whole(value: Variant) -> bool:
	return finite_number(value) and float(value)==floor(float(value))
