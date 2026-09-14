extends RefCounted
## Bounded semantic history for continuous furniture and room-layout edits.

const Inventory = preload("res://scripts/core/furniture_inventory.gd")
const LIMIT := 20

var _undo: Array = []
var _redo: Array = []
var _room_revision_floors: Dictionary = {}
var undo_steps: int:
	get: return _undo.size()
var redo_steps: int:
	get: return _redo.size()

func clear() -> void:
	_undo.clear(); _redo.clear(); _room_revision_floors.clear()

func checkpoint() -> Dictionary:
	return {"undo":_undo.duplicate(true),"redo":_redo.duplicate(true),"room_revision_floors":_room_revision_floors.duplicate(true)}

func restore_checkpoint(value: Dictionary) -> void:
	if value.get("undo") is Array and value.get("redo") is Array:
		_undo = value.undo.duplicate(true); _redo = value.redo.duplicate(true)
		_room_revision_floors = value.get("room_revision_floors",{}).duplicate(true) if value.get("room_revision_floors",{}) is Dictionary else {}

func capture(model) -> Dictionary:
	var hotels: Array = []
	for hotel in model.hotels:
		hotels.append({"layout":Array(hotel.get("layout",[])).duplicate(true),"purchases":int(hotel.get("purchases",0))})
	return {"furniture":model.furniture.serialize(),"hotels":hotels}

func record(before: Dictionary, model, cost_units: int) -> void:
	if cost_units < 0 or not before.has("furniture") or not before.has("hotels"): return
	var after := capture(model); _observe_revisions(before); _observe_revisions(after)
	_undo.append({"before":before.duplicate(true),"after":after,"cost_units":cost_units})
	while _undo.size() > LIMIT: _undo.pop_front()
	_redo.clear()

func _semantic(snapshot: Dictionary) -> Dictionary:
	var furniture: Dictionary = snapshot.get("furniture",{}).duplicate(true)
	furniture.erase("next_instance"); furniture.erase("revision")
	var instances: Array = furniture.get("instances",[])
	instances.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return str(a.uid) < str(b.uid))
	var rooms: Array = []
	for raw in furniture.get("rooms",[]):
		rooms.append({"hotel":int(raw.hotel),"room":int(raw.room)})
	rooms.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.hotel < b.hotel or (a.hotel == b.hotel and a.room < b.room))
	furniture.rooms = rooms
	var licenses: Array = furniture.get("legacy_reuse",[]); licenses.sort(); furniture.legacy_reuse=licenses
	return {"furniture":furniture,"hotels":snapshot.get("hotels",[])}

func _failure(code: String, message: String) -> Dictionary:
	return {"ok":false,"code":code,"message":message}

func _observe_revisions(snapshot: Dictionary) -> void:
	var furniture: Variant = snapshot.get("furniture",{})
	if not furniture is Dictionary or not furniture.get("rooms",[]) is Array: return
	for record in furniture.rooms:
		var key := "%d:%d" % [int(record.hotel),int(record.room)]
		_room_revision_floors[key] = maxi(int(_room_revision_floors.get(key,-1)),int(record.revision))

func _rebased_inventory(target: Dictionary, current: Dictionary) -> Dictionary:
	var result := target.duplicate(true)
	result.next_instance = maxi(int(target.next_instance),int(current.next_instance))
	result.revision = int(current.revision) + 1
	var current_rooms: Dictionary = {}
	for record in current.rooms: current_rooms["%d:%d" % [int(record.hotel),int(record.room)]] = record
	for record in result.rooms:
		var key := "%d:%d" % [int(record.hotel),int(record.room)]
		var prior := maxi(int(record.revision),int(_room_revision_floors.get(key,-1)))
		if current_rooms.has(key): prior = maxi(prior,int(current_rooms[key].revision))
		record.revision = prior + 1
	return result

func _candidate_hotels(model, snapshot: Dictionary) -> Array:
	var result: Array = model.hotels.duplicate(true); var saved: Array = snapshot.get("hotels",[])
	if saved.size() != result.size(): return []
	for index in range(result.size()):
		if not saved[index] is Dictionary or not saved[index].get("layout") is Array: return []
		result[index].layout = saved[index].layout.duplicate(true)
		result[index].purchases = int(saved[index].get("purchases",0))
	return result

func _restore(model, expected: Dictionary, target: Dictionary, cost_units: int, redoing: bool) -> Dictionary:
	var current := capture(model)
	if _semantic(current) != _semantic(expected): return _failure("stale","Building changed since this history step.")
	if redoing and model.coins_units < cost_units: return _failure("unaffordable","You no longer have enough coins to redo this change.")
	var hotels := _candidate_hotels(model,target)
	if hotels.is_empty(): return _failure("invalid_candidate","This history step cannot restore its room layout.")
	_observe_revisions(current)
	var furniture := _rebased_inventory(target.furniture,model.furniture.serialize())
	var validator := Inventory.new()
	if not validator.restore(furniture,hotels): return _failure("invalid_candidate","This history step is no longer valid.")
	for index in range(model.hotels.size()):
		model.hotels[index].layout = hotels[index].layout
		model.hotels[index].purchases = hotels[index].purchases
	model.furniture.state = validator.serialize()
	_observe_revisions(capture(model))
	model.coins_units += -cost_units if redoing else cost_units
	return {"ok":true,"code":"","message":"Redone." if redoing else "Undone."}

func undo(model) -> Dictionary:
	if _undo.is_empty(): return _failure("empty","Nothing to undo.")
	var entry: Dictionary = _undo.back()
	var result := _restore(model,entry.after,entry.before,int(entry.cost_units),false)
	if result.ok: _undo.pop_back(); _redo.append(entry)
	return result

func redo(model) -> Dictionary:
	if _redo.is_empty(): return _failure("empty","Nothing to redo.")
	var entry: Dictionary = _redo.back()
	var result := _restore(model,entry.before,entry.after,int(entry.cost_units),true)
	if result.ok: _redo.pop_back(); _undo.append(entry)
	return result
