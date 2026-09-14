extends RefCounted
## One owner per pointer, from press until release. This router never buys or applies.
const TAP_DISTANCE: float = 8.0
var _pointers: Dictionary = {}
var _multi: bool = false
var _blocked_multi: bool = false
var _geometry: String = ""

func reset() -> void:
	_pointers.clear()
	_multi = false
	_blocked_multi = false

func pointer_count() -> int:
	return _pointers.size()

func feed(event: InputEvent, context: Dictionary) -> Array:
	var geometry: String = str(context.get("metrics_generation",context.world_rect))+":"+str(context.get("ui_scale",1.0))
	if _geometry!="" and geometry!=_geometry:
		var captured: bool = not _pointers.is_empty()
		reset()
		_geometry = geometry
		if captured: return []
	_geometry = geometry
	var mobile: bool = context.get("mobile",false)
	if mobile and (event is InputEventMouseButton or event is InputEventMouseMotion): return []
	if event is InputEventScreenTouch:
		if event.canceled:
			reset()
			return []
		return _press(event.index,event.position,context) if event.pressed else _release(event.index,event.position,context)
	if event is InputEventScreenDrag:
		return _drag(event.index,event.position,event.relative,context)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			return _press(-1,event.position,context) if event.pressed else _release(-1,event.position,context)
		if event.pressed and context.world_rect.has_point(event.position):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP: return [{"kind":"zoom","factor":1.08}]
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: return [{"kind":"zoom","factor":1.0/1.08}]
	if event is InputEventMouseMotion:
		return _drag(-1,event.position,event.relative,context)
	if event is InputEventMagnifyGesture and context.world_rect.has_point(event.position):
		return [{"kind":"zoom","factor":maxf(0.01,event.factor)}]
	return []

func _press(id: int, point: Vector2, context: Dictionary) -> Array:
	if _pointers.has(id): return []
	var in_world: bool = context.world_rect.has_point(point)
	var handle: Rect2 = context.get("move_rect",Rect2())
	_pointers[id] = {"point":point,"start":point,"distance":0.0,"world":in_world,"move":in_world and handle.has_point(point)}
	if _pointers.size()>=2: _multi = true
	if _pointers.size()>2: _blocked_multi = true
	return []

func _release(id: int, point: Vector2, context: Dictionary) -> Array:
	if not _pointers.has(id): return []
	var pointer: Dictionary = _pointers[id]
	var tap: bool = not _multi and pointer.world and pointer.distance < TAP_DISTANCE / maxf(0.1,context.get("ui_scale",1.0)) and context.world_rect.has_point(point)
	_pointers.erase(id)
	if _pointers.is_empty(): reset()
	return [{"kind":"tap_world","position":point}] if tap else []

func _drag(id: int, point: Vector2, relative: Vector2, context: Dictionary) -> Array:
	if not _pointers.has(id): return []
	var pointer: Dictionary = _pointers[id]
	pointer.distance += relative.length()
	if not context.world_rect.has_point(point): pointer.world = false
	if _multi:
		if _pointers.size()!=2 or _blocked_multi:
			pointer.point = point
			return []
		var values: Array = _pointers.values()
		var before_distance: float = values[0].point.distance_to(values[1].point)
		var before_center: Vector2 = (values[0].point+values[1].point)*0.5
		pointer.point = point
		if not values[0].world or not values[1].world: return []
		var after_distance: float = values[0].point.distance_to(values[1].point)
		var center: Vector2 = (values[0].point+values[1].point)*0.5
		var result: Array = [{"kind":"pan","relative":center-before_center}]
		if before_distance>1 and after_distance>1: result.append({"kind":"zoom","factor":after_distance/before_distance})
		return result
	pointer.point = point
	if not pointer.world or pointer.distance < TAP_DISTANCE / maxf(0.1,context.get("ui_scale",1.0)): return []
	if not context.world_rect.has_point(point): return []
	return [{"kind":"move_ghost","position":point}] if pointer.move else [{"kind":"pan","relative":relative}]
