extends RefCounted
## Detached, recoverable editing state for one room.
##
## Version-one drafts put the inventory receipt fields at the top level. `original`
## is the room snapshot, `storage` is the begin-time storage snapshot, `undo` and
## `redo` are arrays of complete draft-instance states, and `next_draft` is the
## next stable `draft:<edit_id>:n` suffix.

const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const Layout = preload("res://scripts/core/furniture_layout.gd")
const HISTORY_LIMIT := 20

var hotel: int = -1
var room: int = -1
var instances: Array = []
var edit_id: String = ""
var base_room_revision: int = -1
var base_inventory_revision: int = -1
var changed_count: int = 0
var undo_steps: int = 0
var redo_steps: int = 0

var _original: Array = []
var _storage: Array = []
var _undo: Array = []
var _redo: Array = []
var _next_draft: int = 0
var _room_data: Dictionary = {}

func begin(model, target_hotel: int, target_room: int, target_edit_id: String) -> void:
	hotel = target_hotel
	room = target_room
	edit_id = target_edit_id
	instances = model.furniture.room_items(hotel,room).duplicate(true)
	_original = instances.duplicate(true)
	_storage = model.furniture.stored_items().duplicate(true)
	var record: Dictionary = model.furniture.room_record(hotel,room)
	base_room_revision = int(record.get("revision",-1))
	base_inventory_revision = int(model.furniture.state.get("revision",-1))
	_room_data = _model_room(model,hotel,room).duplicate(true)
	_undo = []
	_redo = []
	_next_draft = 0
	_refresh_metadata()

func _model_room(model, target_hotel: int, target_room: int) -> Dictionary:
	if target_hotel < 0 or target_hotel >= model.hotels.size(): return {}
	if target_room == -2: return preload("res://scripts/core/shared_layout.gd").data(model.hotels,target_hotel)
	var rooms: Variant = model.hotels[target_hotel].get("layout",[])
	if not rooms is Array or target_room < 0 or target_room >= rooms.size(): return {}
	return rooms[target_room] if rooms[target_room] is Dictionary else {}

func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

func _failure(code: String, message: String) -> Dictionary:
	return {"ok":false,"code":code,"message":message}

func _find(uid: String) -> int:
	for index in range(instances.size()):
		if str(instances[index].get("uid","")) == uid: return index
	return -1

func _stored(uid: String) -> Dictionary:
	for value in _storage:
		if str(value.get("uid","")) == uid: return value
	return {}

func _position_payload(payload: Dictionary, keys: Array[String]) -> Dictionary:
	for key in keys:
		if not payload.has(key): return _failure("invalid_payload","This edit is incomplete.")
	for key in ["x","y"]:
		if keys.has(key) and not _whole(payload[key]): return _failure("invalid_payload","Use whole grid coordinates.")
	if keys.has("rotation") and not _whole(payload.rotation): return _failure("invalid_payload","Use a whole rotation.")
	return {"ok":true}

func edit(command: String, payload: Dictionary) -> Dictionary:
	var candidate: Array = instances.duplicate(true)
	match command:
		"add":
			var shape := _position_payload(payload,["x","y","rotation"])
			if not shape.ok or not payload.get("item") is String: return shape if not shape.ok else _failure("invalid_payload","Choose valid furniture.")
			var definition := Catalog.item(str(payload.item))
			if definition.is_empty() or bool(definition.included_only): return _failure("invalid_item","Choose valid catalogue furniture.")
			var uid := "draft:%s:%d" % [edit_id,_next_draft]
			candidate.append({"uid":uid,"item":str(payload.item),"hotel":hotel,"room":room,"x":int(payload.x),"y":int(payload.y),"rotation":int(payload.rotation)})
		"move", "transform":
			var shape := _position_payload(payload,["x","y"])
			if not shape.ok or not payload.get("uid") is String: return shape if not shape.ok else _failure("invalid_payload","Choose an object.")
			var index := _find(str(payload.uid))
			if index < 0: return _failure("unknown_uid","This object is no longer in the draft.")
			candidate[index].x=int(payload.x); candidate[index].y=int(payload.y)
			if command == "transform":
				if not _whole(payload.get("rotation")): return _failure("invalid_payload","Use a whole rotation.")
				candidate[index].rotation=int(payload.rotation)
		"rotate":
			var shape := _position_payload(payload,["rotation"])
			if not shape.ok or not payload.get("uid") is String: return shape if not shape.ok else _failure("invalid_payload","Choose an object.")
			var index := _find(str(payload.uid))
			if index < 0: return _failure("unknown_uid","This object is no longer in the draft.")
			candidate[index].rotation=int(payload.rotation)
		"store":
			if not payload.get("uid") is String: return _failure("invalid_payload","Choose an object.")
			var index := _find(str(payload.uid))
			if index < 0: return _failure("unknown_uid","This object is no longer in the draft.")
			candidate.remove_at(index)
		"place_stored":
			var shape := _position_payload(payload,["x","y","rotation"])
			if not shape.ok or not payload.get("uid") is String: return shape if not shape.ok else _failure("invalid_payload","Choose stored furniture.")
			var uid := str(payload.uid); var source := _stored(uid)
			if source.is_empty() or _find(uid) >= 0: return _failure("unknown_uid","This furniture is not available in storage.")
			candidate.append({"uid":uid,"item":str(source.item),"hotel":hotel,"room":room,"x":int(payload.x),"y":int(payload.y),"rotation":int(payload.rotation)})
		_:
			return _failure("unknown_command","This edit command is not supported.")
	var validation := Layout.validate(_room_data,candidate,false)
	if not validation.ok: return _failure(str(validation.code),str(validation.message))
	_push_undo(instances)
	instances = candidate
	_redo.clear()
	if command == "add": _next_draft += 1
	_refresh_metadata()
	return {"ok":true,"code":"","message":"Draft updated."}

func _push_undo(state: Array) -> void:
	_undo.append(state.duplicate(true))
	if _undo.size() > HISTORY_LIMIT: _undo.pop_front()

func undo() -> bool:
	if _undo.is_empty(): return false
	_redo.append(instances.duplicate(true))
	instances = _undo.pop_back()
	_refresh_metadata()
	return true

func redo() -> bool:
	if _redo.is_empty(): return false
	_push_undo(instances)
	instances = _redo.pop_back()
	_refresh_metadata()
	return true

func quote(model) -> Dictionary:
	return model.furniture.quote(model,hotel,room,instances.duplicate(true))

func patch() -> Dictionary:
	return {"hotel":hotel,"room":room,"edit_id":edit_id,"base_room_revision":base_room_revision,
		"base_inventory_revision":base_inventory_revision,"instances":instances.duplicate(true)}

func serialize() -> Dictionary:
	var result := patch()
	result.version=1
	result.original=_original.duplicate(true)
	result.storage=_storage.duplicate(true)
	result.undo=_undo.duplicate(true)
	result.redo=_redo.duplicate(true)
	result.next_draft=_next_draft
	return result

func restore(raw: Variant, model) -> Dictionary:
	if not raw is Dictionary or raw.get("version") != 1: return _failure("invalid_draft","This draft cannot be recovered.")
	for key in ["hotel","room","base_room_revision","base_inventory_revision","next_draft"]:
		if not _whole(raw.get(key)) or int(raw[key]) < 0 or float(raw[key]) > 9000000000000000: return _failure("invalid_draft","This draft cannot be recovered.")
	if not raw.get("edit_id") is String or str(raw.edit_id).is_empty() or str(raw.edit_id).length()>256 or str(raw.edit_id).contains(":"): return _failure("invalid_draft","This draft cannot be recovered.")
	for key in ["instances","original","storage","undo","redo"]:
		if not raw.get(key) is Array: return _failure("invalid_draft","This draft cannot be recovered.")
	var target_hotel := int(raw.hotel); var target_room := int(raw.room)
	var record: Dictionary = model.furniture.room_record(target_hotel,target_room)
	if record.is_empty(): return _failure("invalid_room","This room is no longer available.")
	if str(record.get("last_edit_id","")) == str(raw.edit_id): return _failure("already_applied","This draft was already applied.")
	if int(record.get("revision",-1)) != int(raw.base_room_revision) or int(model.furniture.state.get("revision",-1)) != int(raw.base_inventory_revision):
		return _failure("stale","This room changed after the draft was saved.")
	var restored_room := _model_room(model,target_hotel,target_room)
	if restored_room.is_empty() or not _valid_states(raw.instances,raw.undo,raw.redo,restored_room,str(raw.edit_id)):
		return _failure("invalid_draft","This draft cannot be recovered.")
	# At these revisions the source snapshots must match authoritative ownership.
	if not _source_matches(raw.original,model.furniture.room_items(target_hotel,target_room)) or not _source_matches(raw.storage,model.furniture.stored_items()):
		return _failure("invalid_draft","The draft ownership snapshot is invalid.")
	var owned := {}
	for value in raw.original + raw.storage: owned[str(value.uid)]=str(value.item)
	var states: Array = [raw.instances]
	states.append_array(raw.undo); states.append_array(raw.redo)
	var draft_types := {}
	for values in states:
		for value in values:
			var uid := str(value.uid)
			if int(value.get("hotel",-1)) != target_hotel or int(value.get("room",-1)) != target_room: return _failure("invalid_draft","A draft object belongs to another room.")
			if uid.begins_with("draft:"):
				var parts := uid.split(":")
				if parts.size()!=3 or not parts[2].is_valid_int(): return _failure("invalid_draft","An object ID is invalid.")
				var suffix := int(parts[2])
				if suffix<0 or str(suffix)!=parts[2] or suffix>=int(raw.next_draft): return _failure("invalid_draft","The draft object counter is invalid.")
				if Catalog.item(value.item).included_only or (draft_types.has(uid) and draft_types[uid]!=value.item): return _failure("invalid_draft","An object's identity changed.")
				draft_types[uid]=value.item
			elif not owned.has(uid) or owned[uid]!=str(value.item): return _failure("invalid_draft","This object is no longer owned.")
	hotel=target_hotel; room=target_room; edit_id=str(raw.edit_id)
	base_room_revision=int(raw.base_room_revision); base_inventory_revision=int(raw.base_inventory_revision)
	instances=_normalized_state(raw.instances); _original=_normalized_state(raw.original); _storage=_normalized_state(raw.storage)
	_undo=_normalized_history(raw.undo); _redo=_normalized_history(raw.redo); _next_draft=int(raw.next_draft); _room_data=restored_room.duplicate(true)
	_refresh_metadata()
	return {"ok":true,"code":"","message":"Draft recovered."}

func _valid_states(current: Array, undo_values: Array, redo_values: Array, room_value: Dictionary, expected_edit_id: String) -> bool:
	if undo_values.size() > HISTORY_LIMIT or redo_values.size() > HISTORY_LIMIT: return false
	var states: Array = [current]
	states.append_array(undo_values); states.append_array(redo_values)
	for state in states:
		if not state is Array or not Layout.validate(room_value,state,false).ok: return false
		for value in state:
			if not value is Dictionary: return false
			var uid := str(value.get("uid",""))
			if uid.begins_with("draft:") and not uid.begins_with("draft:%s:" % expected_edit_id): return false
	return true

func _source_matches(values: Array, expected: Array) -> bool:
	if values.size()!=expected.size(): return false
	for index in range(values.size()):
		var value = values[index]
		if not value is Dictionary or value.size()!=expected[index].size(): return false
		for key in ["uid","item"]:
			if not value.get(key) is String or value[key]!=expected[index][key]: return false
		for key in ["hotel","room","x","y","rotation"]:
			if not _whole(value.get(key)) or int(value[key])!=int(expected[index][key]): return false
	return true

func _normalized_state(values: Array) -> Array:
	var result: Array = values.duplicate(true)
	for value in result:
		for key in ["hotel","room","x","y","rotation"]:
			if value.has(key): value[key]=int(value[key])
	return result

func _normalized_history(values: Array) -> Array:
	var result: Array = []
	for state in values: result.append(_normalized_state(state))
	return result

func dirty() -> bool:
	return instances != _original

func _refresh_metadata() -> void:
	changed_count = _changed()
	undo_steps = _undo.size()
	redo_steps = _redo.size()

func _changed() -> int:
	var before: Dictionary = {}; var after: Dictionary = {}
	for value in _original: before[str(value.get("uid",""))]=value
	for value in instances: after[str(value.get("uid",""))]=value
	var keys: Dictionary = before.duplicate()
	for uid in after: keys[uid]=true
	var count := 0
	for uid in keys:
		if not before.has(uid) or not after.has(uid) or before[uid] != after[uid]: count += 1
	return count
