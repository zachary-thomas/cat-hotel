extends RefCounted
## Immutable room clipboard validation, pricing, and atomic shell-plus-furniture placement.

const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const FurnitureLayout = preload("res://scripts/core/furniture_layout.gd")
const RoomLayout = preload("res://scripts/core/room_layout.gd")
const Shared = preload("res://scripts/core/shared_layout.gd")

const FIXTURES := {
	"regular":{"room_nightstand":1},
	"suite":{"room_nightstand":1,"suite_sofa":1,"suite_table":1},
}

static func _failure(code: String, message: String, room_cost: int = 0, furniture_cost: int = 0) -> Dictionary:
	return {"ok":false,"code":code,"message":message,"cost_coins":room_cost+furniture_cost,
		"room_cost":room_cost,"furniture_cost":furniture_cost}

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func capture(model, hotel: int, room: int) -> Dictionary:
	if hotel < 0 or hotel >= model.hotels.size() or model.hotels[hotel].get("owned") != true:
		return {}
	var rooms: Array = RoomLayout.entries(model,hotel)
	if room < 0 or room >= rooms.size() or model.furniture.room_record(hotel,room).is_empty():
		return {}
	var items: Array = []
	for instance in model.furniture.room_items(hotel,room):
		items.append({"item":str(instance.item),"x":int(instance.x),"y":int(instance.y),"rotation":int(instance.rotation)})
	return {"version":1,"kind":str(rooms[room].kind),"items":items,"name":"Copy of Room %02d" % (room+1)}

static func _normalize(model, hotel: int, blueprint: Variant) -> Dictionary:
	if not blueprint is Dictionary or not _whole(blueprint.get("version")) or int(blueprint.version) != 1:
		return _failure("invalid_blueprint","This room copy is invalid.")
	if not blueprint.get("kind") is String or blueprint.kind not in ["regular","suite"] or not blueprint.get("items") is Array:
		return _failure("invalid_blueprint","This room copy is invalid.")
	if not blueprint.get("name","") is String or str(blueprint.get("name","")).length() > 128:
		return _failure("invalid_blueprint","This room copy is invalid.")
	if hotel < 0 or hotel >= model.hotels.size() or model.hotels[hotel].get("owned") != true:
		return _failure("invalid_hotel","Choose an open hotel first.")
	var allowed: Dictionary = FIXTURES[str(blueprint.kind)]
	var fixture_counts: Dictionary = {}
	var normalized: Array = []
	var furniture_cost := 0
	for index in range(blueprint.items.size()):
		var raw: Variant = blueprint.items[index]
		if not raw is Dictionary or not raw.get("item") is String:
			return _failure("invalid_item","This room copy contains invalid furniture.")
		var definition: Dictionary = Catalog.item(str(raw.item))
		if definition.is_empty():
			return _failure("invalid_item","This room copy contains unknown furniture.")
		if definition.included_only:
			if not allowed.has(raw.item):
				return _failure("invalid_fixture","This fixture does not belong in this room type.")
			fixture_counts[raw.item] = int(fixture_counts.get(raw.item,0)) + 1
			if int(fixture_counts[raw.item]) > int(allowed[raw.item]):
				return _failure("invalid_fixture","A room copy cannot create extra included fixtures.")
		elif int(definition.bond) > 0 and not model.furniture.state.legacy_reuse.has(raw.item):
			return _failure("locked","Earn this friendship furnishing before copying it.")
		elif model.hotel_level(hotel) < int(definition.level):
			return _failure("locked","This furnishing is still locked.")
		elif not model.furniture.state.legacy_reuse.has(raw.item):
			furniture_cost += int(definition.cost)
		normalized.append({"uid":"blueprint:%d" % index,"item":str(raw.item),"hotel":hotel,"room":0,
			"x":raw.get("x"),"y":raw.get("y"),"rotation":raw.get("rotation")})
	var interior := FurnitureLayout.validate({"kind":str(blueprint.kind),"x":0,"y":0,"rotation":0},normalized)
	if not interior.ok:
		return _failure(str(interior.code),str(interior.message))
	return {"ok":true,"code":"","message":"Room copy is valid.","items":normalized,"furniture_cost":furniture_cost}

static func quote(model, hotel: int, blueprint: Dictionary, candidate: Dictionary) -> Dictionary:
	var normalized := _normalize(model,hotel,blueprint)
	if not normalized.ok:
		return normalized
	if not candidate is Dictionary or candidate.get("kind") != blueprint.kind:
		return _failure("kind_mismatch","Place this copy as the same room type.")
	var shell := {"kind":str(blueprint.kind),"x":candidate.get("x"),"y":candidate.get("y"),"rotation":candidate.get("rotation")}
	var outer := RoomLayout.validate(model,hotel,shell)
	var room_cost := RoomLayout.cost(str(blueprint.kind))
	var furniture_cost: int = int(normalized.furniture_cost)
	# Resolve shared-floor conflicts against the future shell to retain the
	# actionable collision/route code even when RoomLayout reports its generic
	# shared-furniture placement message.
	if outer.ok or str(outer.message).contains("shared furniture"):
		var future_hotels: Array = model.hotels.duplicate(true)
		var future_layout: Array = Array(future_hotels[hotel].get("layout",[])).duplicate(true)
		future_layout.append(shell.duplicate(true))
		future_hotels[hotel].layout = future_layout
		var shared_validation: Dictionary = Shared.validate(Shared.data(future_hotels,hotel),model.furniture.room_items(hotel,-2),false)
		if not shared_validation.ok:
			return _failure(str(shared_validation.code),str(shared_validation.message),room_cost,furniture_cost)
	if not outer.ok:
		var code := "invalid_placement"
		if str(outer.message).contains("overlaps"): code="overlap"
		elif str(outer.message).contains("wing"): code="locked_floor"
		elif str(outer.message).contains("eight rooms"): code="room_limit"
		return _failure(code,str(outer.message),room_cost,furniture_cost)
	var total := room_cost + furniture_cost
	if model.coins_units < total * model.UNIT:
		return _failure("unaffordable","You need %d coins to place this room copy." % total,room_cost,furniture_cost)
	return {"ok":true,"code":"","message":"Ready to place.","cost_coins":total,
		"room_cost":room_cost,"furniture_cost":furniture_cost}

static func _restore(model, snapshot: Dictionary, notices: Array) -> void:
	model.restore(snapshot)
	model.life.notices = notices.duplicate(true)

static func place(model, hotel: int, blueprint: Dictionary, candidate: Dictionary) -> Dictionary:
	var priced := quote(model,hotel,blueprint,candidate)
	if not priced.ok:
		return {"ok":false,"code":priced.code,"message":priced.message,"cost_coins":priced.cost_coins,"room":-1}
	var normalized := _normalize(model,hotel,blueprint)
	if not normalized.ok:
		return {"ok":false,"code":normalized.code,"message":normalized.message,"cost_coins":0,"room":-1}
	var snapshot: Dictionary = model.serialize()
	var notices: Array = model.life.notices.duplicate(true)
	var payload := {"hotel":hotel,"kind":str(blueprint.kind),"x":candidate.get("x"),
		"y":candidate.get("y"),"rotation":candidate.get("rotation")}
	var built := RoomLayout.perform(model,"place_room",payload)
	if not built.ok:
		_restore(model,snapshot,notices)
		return {"ok":false,"code":"placement_changed","message":str(built.message),"cost_coins":int(priced.cost_coins),"room":-1}
	var room: int = int(built.room)
	var inventory: Dictionary = model.furniture.serialize()
	var granted: Dictionary = {}
	var kept: Array = []
	for instance in inventory.instances:
		if int(instance.hotel) == hotel and int(instance.room) == room:
			if Catalog.item(str(instance.item)).included_only:
				granted[str(instance.item)] = instance.duplicate(true)
		else:
			kept.append(instance)
	var copied: Array = []
	for raw in normalized.items:
		var value := {"item":str(raw.item),"hotel":hotel,"room":room,"x":int(raw.x),"y":int(raw.y),"rotation":int(raw.rotation)}
		if Catalog.item(str(raw.item)).included_only:
			if not granted.has(raw.item):
				_restore(model,snapshot,notices)
				return {"ok":false,"code":"fixture_changed","message":"This room's fixtures changed.","cost_coins":int(priced.cost_coins),"room":-1}
			value.uid = granted[raw.item].uid
		else:
			value.uid = "f%d" % int(inventory.next_instance)
			inventory.next_instance = int(inventory.next_instance) + 1
		copied.append(value)
	kept.append_array(copied)
	inventory.instances = kept
	inventory.revision = int(inventory.revision) + 1
	if not model.furniture.restore(inventory,model.hotels):
		_restore(model,snapshot,notices)
		return {"ok":false,"code":"invalid_candidate","message":"This room copy could not be placed.","cost_coins":int(priced.cost_coins),"room":-1}
	var charge: int = int(priced.furniture_cost) * int(model.UNIT)
	if charge < 0 or model.coins_units < charge:
		_restore(model,snapshot,notices)
		return {"ok":false,"code":"unaffordable","message":"You do not have enough coins.","cost_coins":int(priced.cost_coins),"room":-1}
	model.coins_units -= charge
	return {"ok":true,"code":"","message":"Room copy placed.","cost_coins":int(priced.cost_coins),"room":room}
