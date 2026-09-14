extends RefCounted
## Authoritative furniture instances, ownership, pricing, and atomic room edits.

const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const Layout = preload("res://scripts/core/furniture_layout.gd")
const RoomLayout = preload("res://scripts/core/room_layout.gd")
const Quality = preload("res://scripts/core/room_quality.gd")
const Life = preload("res://scripts/core/hotel_life.gd")
const STORAGE_CAP := 256
const MAX_NUMBER := 9000000000000000
const STARTER_LICENSES := ["mat", "box", "plant"]
const SHARED_ROOM := -2

var state: Dictionary

func _init() -> void: reset()

func reset() -> void:
	state = {"version":1,"next_instance":1,"revision":0,"legacy_reuse":STARTER_LICENSES.duplicate(),"instances":[],"rooms":[]}

func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

func _room_key(hotel: int, room: int) -> String: return "%d:%d" % [hotel,room]

func room_record(hotel: int, room: int) -> Dictionary:
	if room == SHARED_ROOM and hotel >= 0:
		return {"hotel":hotel,"room":room,"revision":int(state.revision),"last_edit_id":""}
	for value in state.rooms:
		if int(value.hotel) == hotel and int(value.room) == room: return value.duplicate(true)
	return {}

func room_items(hotel: int, room: int) -> Array:
	var result: Array = []
	for value in state.instances:
		if int(value.hotel) == hotel and int(value.room) == room: result.append(value.duplicate(true))
	return result

func stored_items() -> Array:
	var result: Array = []
	for value in state.instances:
		if int(value.hotel) == -1: result.append(value.duplicate(true))
	return result

func serialize() -> Dictionary: return state.duplicate(true)

func _allocate(target: Dictionary) -> String:
	var uid := "f%d" % int(target.next_instance)
	target.next_instance = int(target.next_instance) + 1
	return uid

func _placed(template: Dictionary, target: Dictionary, hotel: int, room: int) -> Dictionary:
	return {"uid":_allocate(target),"item":str(template.item),"hotel":hotel,"room":room,
		"x":int(template.x),"y":int(template.y),"rotation":int(template.rotation)}

func _open_room(hotels: Array, hotel: int, room: int) -> Dictionary:
	if hotel < 0 or hotel >= hotels.size() or not hotels[hotel] is Dictionary or hotels[hotel].get("owned") != true:
		return {}
	if room == SHARED_ROOM:
		var shared = load("res://scripts/core/shared_layout.gd")
		return shared.data(hotels,hotel) if shared != null else {}
	var rooms: Variant = hotels[hotel].get("layout", [])
	if not rooms is Array or room < 0 or room >= rooms.size() or not rooms[room] is Dictionary: return {}
	return rooms[room]

func _valid_candidate(raw: Variant, hotels: Array) -> bool:
	if not raw is Dictionary or raw.get("version") != 1: return false
	for key in ["next_instance","revision"]:
		if not _whole(raw.get(key)) or int(raw[key]) < (1 if key == "next_instance" else 0) or float(raw[key]) > MAX_NUMBER: return false
	if not raw.get("legacy_reuse") is Array or not raw.get("instances") is Array or not raw.get("rooms") is Array: return false
	var licenses: Dictionary = {}
	for id in raw.legacy_reuse:
		var definition: Dictionary = Catalog.item(id) if id is String else {}
		if definition.is_empty() or definition.included_only or licenses.has(id): return false
		licenses[id] = true
	for starter in STARTER_LICENSES:
		if not licenses.has(starter): return false
	var room_keys: Dictionary = {}; var max_uid := 0
	for value in raw.rooms:
		if not value is Dictionary: return false
		for key in ["hotel","room","revision"]:
			if not _whole(value.get(key)) or int(value[key]) < 0 or float(value[key]) > MAX_NUMBER: return false
		if not value.get("last_edit_id") is String or str(value.last_edit_id).length() > 256: return false
		if _open_room(hotels,int(value.hotel),int(value.room)).is_empty(): return false
		var room_key := _room_key(int(value.hotel),int(value.room))
		if room_keys.has(room_key): return false
		room_keys[room_key] = true
	for hotel in range(hotels.size()):
		if not hotels[hotel] is Dictionary or hotels[hotel].get("owned") != true: continue
		var open_rooms: Variant = hotels[hotel].get("layout",[])
		if not open_rooms is Array: return false
		for room in range(open_rooms.size()):
			if not room_keys.has(_room_key(hotel,room)): return false
	var uids: Dictionary = {}; var grouped: Dictionary = {}; var storage_count := 0
	for value in raw.instances:
		if not value is Dictionary or not value.get("uid") is String or not str(value.uid).begins_with("f") or not str(value.uid).substr(1).is_valid_int(): return false
		var number := int(str(value.uid).substr(1))
		if number <= 0 or str(value.uid) != "f%d" % number or uids.has(value.uid): return false
		uids[value.uid] = true; max_uid = maxi(max_uid,number)
		if not value.get("item") is String or Catalog.item(value.item).is_empty(): return false
		for key in ["hotel","room","x","y","rotation"]:
			if not _whole(value.get(key)) or absf(float(value[key])) > MAX_NUMBER: return false
		var hotel := int(value.hotel); var room := int(value.room)
		if hotel == -1 and room != -1: return false
		if hotel != -1 and room == -1: return false
		if hotel == -1:
			if int(value.x) != 0 or int(value.y) != 0 or int(value.rotation) != 0: return false
			storage_count += 1
		elif room == SHARED_ROOM:
			if _open_room(hotels,hotel,room).is_empty(): return false
			var shared_key := _room_key(hotel,room)
			if not grouped.has(shared_key): grouped[shared_key] = []
			grouped[shared_key].append(value)
		else:
			var key := _room_key(hotel,room)
			if not room_keys.has(key): return false
			if not grouped.has(key): grouped[key] = []
			grouped[key].append(value)
	if storage_count > STORAGE_CAP or int(raw.next_instance) <= max_uid: return false
	for key in grouped:
		var parts: PackedStringArray = str(key).split(":"); var hotel := int(parts[0]); var room := int(parts[1])
		if room == SHARED_ROOM:
			var shared = load("res://scripts/core/shared_layout.gd")
			if shared == null or not shared.validate(_open_room(hotels,hotel,room),grouped[key],false).ok: return false
		elif not Layout.validate(_open_room(hotels,hotel,room),grouped[key]).ok: return false
	for key in room_keys:
		if not grouped.has(key) or not Layout.validate(_open_room(hotels,int(str(key).get_slice(":",0)),int(str(key).get_slice(":",1))),grouped[key]).ok: return false
	return true

func _location_validation(hotels: Array, hotel: int, room: int, instances: Array) -> Dictionary:
	var data := _open_room(hotels,hotel,room)
	if data.is_empty(): return {"ok":false,"code":"invalid_room","message":"Choose an open room or shared floor."}
	if room == SHARED_ROOM:
		var shared = load("res://scripts/core/shared_layout.gd")
		return shared.validate(data,instances,false) if shared != null else {"ok":false,"code":"invalid_room","message":"Shared furnishing is unavailable."}
	return Layout.validate(data,instances)

func transfer(model, hotel: int, source_room: int, target_room: int, uid: String, x: int, y: int, rotation: int) -> Dictionary:
	var failure := {"ok":false,"code":"invalid_item","message":"Choose furniture from its current room.","room":target_room,"already_applied":false}
	if source_room < SHARED_ROOM or target_room < SHARED_ROOM or source_room == -1 or target_room == -1:
		failure.code = "invalid_room"; failure.message = "Choose an open room or shared floor."; return failure
	var source_record := room_record(hotel,source_room); var target_record := room_record(hotel,target_room)
	if source_record.is_empty() or target_record.is_empty(): failure.code="invalid_room"; failure.message="Choose an open room or shared floor."; return failure
	var candidate := state.duplicate(true); var found := false
	for instance in candidate.instances:
		if str(instance.uid) != uid: continue
		if int(instance.hotel) != hotel or int(instance.room) != source_room: return failure
		instance.hotel=hotel; instance.room=target_room; instance.x=x; instance.y=y; instance.rotation=rotation; found=true; break
	if not found: return failure
	var source_items: Array = []; var target_items: Array = []
	for instance in candidate.instances:
		if int(instance.hotel) == hotel and int(instance.room) == source_room: source_items.append(instance)
		if int(instance.hotel) == hotel and int(instance.room) == target_room: target_items.append(instance)
	var source_check := _location_validation(model.hotels,hotel,source_room,source_items)
	if not source_check.ok: return {"ok":false,"code":source_check.code,"message":source_check.message,"room":source_room,"already_applied":false}
	if target_room != source_room:
		var target_check := _location_validation(model.hotels,hotel,target_room,target_items)
		if not target_check.ok: return {"ok":false,"code":target_check.code,"message":target_check.message,"room":target_room,"already_applied":false}
	candidate.revision = int(candidate.revision) + 1
	for record in candidate.rooms:
		if int(record.hotel) == hotel and (int(record.room) == source_room or int(record.room) == target_room):
			record.revision = int(record.revision) + 1; record.last_edit_id = ""
	if not _valid_candidate(candidate,model.hotels): return {"ok":false,"code":"invalid_candidate","message":"This move could not be applied.","room":target_room,"already_applied":false}
	state = candidate
	return {"ok":true,"code":"","message":"Furniture moved.","room":target_room,"already_applied":false}

func restore(raw: Variant, hotels: Array) -> bool:
	if not _valid_candidate(raw,hotels): return false
	var candidate: Dictionary = raw.duplicate(true)
	candidate.next_instance = int(candidate.next_instance); candidate.revision = int(candidate.revision)
	for record in candidate.rooms:
		for key in ["hotel","room","revision"]: record[key] = int(record[key])
	for instance in candidate.instances:
		for key in ["hotel","room","x","y","rotation"]: instance[key] = int(instance[key])
	state = candidate
	return true

func migrate(legacy_model: Dictionary) -> Dictionary:
	if not _whole(legacy_model.get("version")) or int(legacy_model.version) not in [1,2] or not legacy_model.get("hotels") is Array:
		return {"ok":false,"state":{},"message":"This save cannot be converted."}
	if int(legacy_model.version) == 2:
		var restored_life := Life.new()
		if not restored_life.restore(legacy_model.get("life")):
			return {"ok":false,"state":{},"message":"This save's furniture ownership is incomplete."}
	var candidate := {"version":1,"next_instance":1,"revision":0,"legacy_reuse":STARTER_LICENSES.duplicate(),"instances":[],"rooms":[]}
	var life: Dictionary = legacy_model.get("life", {}) if legacy_model.get("life") is Dictionary else {}
	for id in life.get("furniture", STARTER_LICENSES):
		if id is String and not Catalog.item(id).is_empty() and not candidate.legacy_reuse.has(id): candidate.legacy_reuse.append(id)
	var life_hotels: Array = life.get("hotels", []) if life.get("hotels") is Array else []
	for hotel in range(legacy_model.hotels.size()):
		var hotel_data: Dictionary = legacy_model.hotels[hotel]
		if hotel_data.get("owned") != true: continue
		var rooms: Array = hotel_data.get("layout", [])
		var saved_rooms: Array = life_hotels[hotel].get("rooms",[]) if hotel < life_hotels.size() and life_hotels[hotel] is Dictionary else []
		for room in range(rooms.size()):
			if int(legacy_model.version) == 2 and (room >= saved_rooms.size() or not saved_rooms[room] is Array or saved_rooms[room].size() != 3):
				return {"ok":false,"state":{},"message":"An open room's furniture ownership is incomplete."}
			candidate.rooms.append({"hotel":hotel,"room":room,"revision":0,"last_edit_id":""})
			var trio: Array = saved_rooms[room].duplicate() if room < saved_rooms.size() and saved_rooms[room] is Array else STARTER_LICENSES.duplicate()
			if int(legacy_model.version) == 2:
				for id in trio:
					if not candidate.legacy_reuse.has(id): return {"ok":false,"state":{},"message":"Placed furniture is missing its ownership license."}
			var template := Layout.template(str(rooms[room].get("kind","regular")),trio)
			if template.is_empty(): return {"ok":false,"state":{},"message":"A legacy room could not be placed safely."}
			for value in template: candidate.instances.append(_placed(value,candidate,hotel,room))
	if not _valid_candidate(candidate,legacy_model.hotels): return {"ok":false,"state":{},"message":"The converted furniture is invalid."}
	return {"ok":true,"state":candidate,"message":"Furniture converted."}

func ensure_rooms(model, hotel: int) -> bool:
	if hotel < 0 or hotel >= model.hotels.size() or model.hotels[hotel].get("owned") != true: return false
	var candidate := state.duplicate(true)
	var rooms: Array = RoomLayout.entries(model,hotel)
	for room in range(rooms.size()):
		var exists := false
		for record in candidate.rooms:
			if int(record.hotel) == hotel and int(record.room) == room: exists=true; break
		if exists: continue
		candidate.rooms.append({"hotel":hotel,"room":room,"revision":0,"last_edit_id":""})
		for value in Layout.template(str(rooms[room].kind)): candidate.instances.append(_placed(value,candidate,hotel,room))
	if not _valid_candidate(candidate,model.hotels): return false
	state = candidate
	return true

func _failure(code: String, message: String) -> Dictionary:
	return {"ok":false,"code":code,"message":message,"cost_coins":0,"purchases":[],"stored_uids":[],"moved_uids":[],"report":{}}

func quote(model, hotel: int, room: int, draft: Array) -> Dictionary:
	var room_data := _open_room(model.hotels,hotel,room)
	if room_data.is_empty() or room_record(hotel,room).is_empty(): return _failure("invalid_room","Choose an open room.")
	var owned: Dictionary = {}; var current: Dictionary = {}
	for value in state.instances: owned[str(value.uid)] = value
	for value in room_items(hotel,room): current[str(value.uid)] = value
	var seen: Dictionary = {}; var normalized: Array = []; var purchases: Array = []; var moved: Array = []; var cost := 0
	for raw in draft:
		if not raw is Dictionary or not raw.get("uid") is String or not raw.get("item") is String: return _failure("invalid_item","Choose valid furniture.")
		var uid: String = raw.uid; var item: String = raw.item
		if seen.has(uid): return _failure("duplicate_uid","An object appears twice.")
		seen[uid] = true
		var definition := Catalog.item(item)
		if definition.is_empty(): return _failure("invalid_item","Choose valid furniture.")
		if uid.begins_with("draft:"):
			var draft_parts: PackedStringArray = uid.split(":")
			if draft_parts.size() != 3 or draft_parts[1].is_empty() or not draft_parts[2].is_valid_int() or int(draft_parts[2]) < 0: return _failure("invalid_uid","This draft item is invalid.")
			if definition.included_only: return _failure("included_only","Included fixtures cannot be added from the catalogue.")
			if int(definition.bond) > 0 and not state.legacy_reuse.has(item): return _failure("locked","Earn this friendship furnishing before placing it.")
			if model.hotel_level(hotel) < int(definition.level): return _failure("locked","This furnishing is still locked.")
			if not state.legacy_reuse.has(item): cost += int(definition.cost)
			purchases.append(item)
		elif not owned.has(uid): return _failure("unknown_uid","This furniture is no longer owned.")
		else:
			var source: Dictionary = owned[uid]
			if str(source.item) != item: return _failure("identity_changed","An object's type cannot change.")
			if int(source.hotel) != -1 and (int(source.hotel) != hotel or int(source.room) != room): return _failure("borrowed","Store furniture before moving it between rooms.")
			if int(source.hotel) == -1: moved.append(uid)
		var value := {"uid":uid,"item":item,"hotel":hotel,"room":room,"x":raw.get("x"),"y":raw.get("y"),"rotation":raw.get("rotation")}
		normalized.append(value)
	var validation := Layout.validate(room_data,normalized)
	if not validation.ok: return _failure(str(validation.code),str(validation.message))
	var stored: Array = []
	for uid in current:
		if not seen.has(uid): stored.append(uid)
	if stored_items().size() + stored.size() - moved.size() > STORAGE_CAP: return _failure("storage_full","Furniture storage is full.")
	var result := {"ok":true,"code":"","message":"Ready to apply.","cost_coins":cost,"purchases":purchases,
		"stored_uids":stored,"moved_uids":moved,"report":Quality.summarize(normalized)}
	if model.coins_units < cost * model.UNIT:
		result.ok = false; result.code = "unaffordable"; result.message = "You need %d coins." % cost
	return result

func apply(model, edit: Dictionary) -> Dictionary:
	for key in ["hotel","room","base_room_revision","base_inventory_revision"]:
		if not _whole(edit.get(key)): return {"ok":false,"code":"invalid_edit","message":"This edit is invalid.","room":-1,"already_applied":false}
	if not edit.get("edit_id") is String or str(edit.edit_id).is_empty() or not edit.get("instances") is Array:
		return {"ok":false,"code":"invalid_edit","message":"This edit is invalid.","room":-1,"already_applied":false}
	var hotel := int(edit.hotel); var room := int(edit.room); var record := room_record(hotel,room)
	if record.is_empty(): return {"ok":false,"code":"invalid_room","message":"Choose an open room.","room":room,"already_applied":false}
	if str(record.last_edit_id) == str(edit.edit_id): return {"ok":true,"code":"","message":"Already applied.","room":room,"already_applied":true}
	if int(record.revision) != int(edit.base_room_revision) or int(state.revision) != int(edit.base_inventory_revision):
		return {"ok":false,"code":"stale","message":"Reload this room before applying.","room":room,"already_applied":false}
	var priced := quote(model,hotel,room,edit.instances)
	if not priced.ok: return {"ok":false,"code":priced.code,"message":priced.message,"room":room,"already_applied":false}
	if edit.has("cost_coins") and (not _whole(edit.cost_coins) or int(edit.cost_coins) != int(priced.cost_coins)):
		return {"ok":false,"code":"price_changed","message":"The furniture price changed. Review the updated total.","room":room,"already_applied":false}
	var candidate := state.duplicate(true); var replacements: Array = []
	for raw in edit.instances:
		var value: Dictionary = raw.duplicate(true)
		if str(value.uid).begins_with("draft:"):
			var draft_parts: PackedStringArray = str(value.uid).split(":")
			if draft_parts.size() != 3 or draft_parts[1] != str(edit.edit_id): return {"ok":false,"code":"invalid_uid","message":"This draft item belongs to another edit.","room":room,"already_applied":false}
			value.uid = _allocate(candidate)
		value.hotel=hotel; value.room=room
		for key in ["x","y","rotation"]: value[key]=int(value[key])
		replacements.append(value)
	var keep: Array = []
	var present: Dictionary = {}
	for value in replacements: present[str(value.uid)] = true
	for value in candidate.instances:
		if int(value.hotel) == hotel and int(value.room) == room:
			if not present.has(str(value.uid)):
				var stored: Dictionary = value.duplicate(true); stored.hotel=-1; stored.room=-1; stored.x=0; stored.y=0; stored.rotation=0; keep.append(stored)
		elif present.has(str(value.uid)):
			pass
		else: keep.append(value)
	for value in replacements: keep.append(value)
	candidate.instances = keep; candidate.revision = int(candidate.revision) + 1
	for candidate_record in candidate.rooms:
		if int(candidate_record.hotel) == hotel and int(candidate_record.room) == room:
			candidate_record.revision = int(candidate_record.revision) + 1; candidate_record.last_edit_id = str(edit.edit_id)
	if not _valid_candidate(candidate,model.hotels): return {"ok":false,"code":"invalid_candidate","message":"This edit could not be applied.","room":room,"already_applied":false}
	var charge := int(priced.cost_coins) * int(model.UNIT)
	if charge < 0 or model.coins_units < charge: return {"ok":false,"code":"unaffordable","message":"You do not have enough coins.","room":room,"already_applied":false}
	model.coins_units -= charge
	state = candidate
	return {"ok":true,"code":"","message":"Room updated.","room":room,"already_applied":false}
