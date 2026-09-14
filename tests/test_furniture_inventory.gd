extends SceneTree

const Inventory = preload("res://scripts/core/furniture_inventory.gd")
const RoomLayout = preload("res://scripts/core/room_layout.gd")

class FakeModel:
	const UNIT := 1000000
	var coins_units := 1000 * UNIT
	var hotels := [{"owned":true,"zones":[1,0,0,0],"purchases":0,"wings":0,"layout":[
		{"kind":"regular","x":0,"y":9,"rotation":0},
		{"kind":"regular","x":6,"y":9,"rotation":2}]}]
	func room_count(hotel: int) -> int: return hotels[hotel].layout.size() if hotel == 0 else 0
	func hotel_level(_hotel: int) -> int: return 1

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	test_migration_preserves_real_rooms_and_licenses()
	test_migration_rejects_incomplete_v2_ownership()
	test_restore_is_atomic_and_strict()
	test_restore_bounds_and_storage_capacity()
	test_ensure_rooms_is_idempotent()
	test_quote_prices_copies_and_rejects_fabrication()
	test_apply_is_atomic_and_idempotent()
	quit(1 if failures else 0)

func legacy_v2() -> Dictionary:
	return saved_fixture("legacy_build_v2")

func saved_fixture(name: String) -> Dictionary:
	var file := FileAccess.open("res://tests/fixtures/%s.json" % name,FileAccess.READ)
	return JSON.parse_string(file.get_as_text())

func find_item(values: Array, item: String) -> Dictionary:
	for value in values:
		if value.item == item: return value
	return {}

func test_migration_preserves_real_rooms_and_licenses() -> void:
	var old := legacy_v2(); var original := old.duplicate(true)
	var result := Inventory.new().migrate(old)
	check(result.ok and old == original, "Migration builds an immutable candidate")
	check(result.state.legacy_reuse.has("heated") and result.state.legacy_reuse.has("lamp"), "Unused and equipped legacy ownership remains reusable")
	var first: Array = result.state.instances.filter(func(v): return v.hotel == 0 and v.room == 0)
	check(first.size() == 4 and not find_item(first,"heated").is_empty() and not find_item(first,"room_nightstand").is_empty(), "Migration uses the actual legacy trio plus its included fixture")
	check(find_item(first,"mat").is_empty() and find_item(first,"plant").is_empty(), "Migration does not add the default trio")
	var v1 := saved_fixture("legacy_build_v1"); var v1_result := Inventory.new().migrate(v1)
	check(v1_result.ok and v1_result.state.legacy_reuse == ["mat","box","plant"], "Captured v1 receives only its implicit starter licenses")
	check(item_names(v1_result.state.instances,0,0) == ["box","mat","plant","room_nightstand"], "Captured v1 preserves the implicit first-room trio and one fixture")
	var v2 := saved_fixture("legacy_build_v2"); var v2_result := Inventory.new().migrate(v2)
	check(v2_result.ok and Inventory.new().restore(v2_result.state,v2.hotels), "Captured v2 migrates to restorable inventory")
	check(v2_result.state.legacy_reuse == ["mat","box","plant","heated","lamp","sun_cushion","perch","blanket"], "Captured v2 preserves gifted and unused licenses exactly")
	check(item_names(v2_result.state.instances,0,0) == ["box","heated","lamp","room_nightstand"], "Captured v2 preserves its equipped paid trio")
	check(item_names(v2_result.state.instances,0,1) == ["perch","plant","room_nightstand","sun_cushion"], "Captured v2 preserves its moved second-room trio")
	check(item_names(v2_result.state.instances,0,2) == ["box","mat","plant","room_nightstand","suite_sofa","suite_table"], "Captured suite receives its actual trio and each suite fixture once")
	var ids: Dictionary = {}; var fixture_count := 0
	for instance in v2_result.state.instances:
		ids[instance.uid] = true
		if instance.item in ["room_nightstand","suite_sofa","suite_table"]: fixture_count += 1
	check(ids.size() == v2_result.state.instances.size() and fixture_count == 11, "Captured v2 has unique UIDs and exactly one applicable fixture allocation per open room")

func item_names(instances: Array, hotel: int, room: int) -> Array:
	var names: Array = []
	for instance in instances:
		if int(instance.hotel) == hotel and int(instance.room) == room: names.append(str(instance.item))
	names.sort()
	return names

func test_migration_rejects_incomplete_v2_ownership() -> void:
	var valid := legacy_v2()
	for corrupt in [
		{"version":2,"hotels":valid.hotels},
		{"version":2,"hotels":valid.hotels,"life":{"furniture":"mat","hotels":valid.life.hotels}},
		{"version":2,"hotels":valid.hotels,"life":{"furniture":valid.life.furniture,"hotels":[]}},
	]:
		check(not Inventory.new().migrate(corrupt).ok, "Malformed v2 ownership rejects instead of minting starters")
	var missing_license := valid.duplicate(true); missing_license.life.furniture.erase("heated")
	check(not Inventory.new().migrate(missing_license).ok, "A placed type missing from legacy ownership rejects")
	var missing_trio := valid.duplicate(true); missing_trio.life.hotels[0].rooms.pop_back()
	check(not Inventory.new().migrate(missing_trio).ok, "A missing open-room trio rejects")

func test_restore_is_atomic_and_strict() -> void:
	var old := legacy_v2(); var migrated := Inventory.new().migrate(old)
	var inventory := Inventory.new()
	check(inventory.restore(migrated.state,old.hotels), "Migrated inventory validates")
	var before := inventory.serialize()
	var duplicate := before.duplicate(true); duplicate.instances.append(duplicate.instances[0].duplicate(true))
	check(not inventory.restore(duplicate,old.hotels) and inventory.serialize() == before, "Duplicate UIDs reject without mutation")
	var fractional := before.duplicate(true); fractional.instances[0].x = 0.5
	check(not inventory.restore(fractional,old.hotels) and inventory.serialize() == before, "Fractional coordinates reject atomically")
	var mixed := before.duplicate(true); mixed.instances[0].hotel = -1
	check(not inventory.restore(mixed,old.hotels), "Storage sentinels must be paired")
	var future := before.duplicate(true); future.version = 2
	check(not inventory.restore(future,old.hotels), "Unknown inventory versions reject")
	for bad_uid in ["f01","f+1","f-1"]:
		var noncanonical := before.duplicate(true); noncanonical.instances[0].uid = bad_uid
		check(not inventory.restore(noncanonical,old.hotels), "Noncanonical allocated UID %s rejects" % bad_uid)
	var fixture_license := before.duplicate(true); fixture_license.legacy_reuse.append("room_nightstand")
	check(not inventory.restore(fixture_license,old.hotels), "Included fixture types cannot become reusable licenses")
	var missing_starter := before.duplicate(true); missing_starter.legacy_reuse.erase("plant")
	check(not inventory.restore(missing_starter,old.hotels), "Restore preserves the universal starter licenses")

func test_restore_bounds_and_storage_capacity() -> void:
	var old := legacy_v2(); var base: Dictionary = Inventory.new().migrate(old).state
	var exact := base.duplicate(true)
	for index in range(256):
		exact.instances.append({"uid":"f%d" % exact.next_instance,"item":"plant","hotel":-1,"room":-1,"x":0,"y":0,"rotation":0})
		exact.next_instance += 1
	var inventory := Inventory.new()
	check(inventory.restore(exact,old.hotels) and inventory.stored_items().size() == 256, "Storage accepts its exact capacity")
	var overflow := exact.duplicate(true); overflow.instances.append({"uid":"f%d" % overflow.next_instance,"item":"plant","hotel":-1,"room":-1,"x":0,"y":0,"rotation":0}); overflow.next_instance += 1
	check(not inventory.restore(overflow,old.hotels), "Storage rejects the 257th instance")
	var huge := base.duplicate(true); huge.revision = 9000000000000001
	check(not inventory.restore(huge,old.hotels), "Huge revision values reject")
	var negative := base.duplicate(true); negative.rooms[0].revision = -1
	check(not inventory.restore(negative,old.hotels), "Negative room revisions reject")
	var missing_room := base.duplicate(true); missing_room.rooms.pop_back()
	check(not inventory.restore(missing_room,old.hotels), "Every open room requires permanent metadata")

func test_ensure_rooms_is_idempotent() -> void:
	var model := FakeModel.new(); var inventory := Inventory.new()
	check(inventory.ensure_rooms(model,0), "Open rooms receive starters")
	var once := inventory.serialize()
	check(inventory.ensure_rooms(model,0) and inventory.serialize() == once, "Existing room records prevent repeated starter grants")
	check(inventory.room_items(0,0).size() == 4 and inventory.room_record(0,0).revision == 0, "A regular room receives three starters and one fixture")

func test_quote_prices_copies_and_rejects_fabrication() -> void:
	var model := FakeModel.new(); var inventory := Inventory.new(); inventory.ensure_rooms(model,0)
	var current := inventory.room_items(0,0)
	var draft := current.duplicate(true)
	draft.append({"uid":"draft:e1:1","item":"scratch","hotel":0,"room":0,"x":4,"y":2,"rotation":0})
	var quote := inventory.quote(model,0,0,draft)
	check(quote.ok and quote.cost_coins == 140 and quote.purchases.size() == 1, "A new per-copy item uses the catalogue price")
	var free_draft := current.duplicate(true); free_draft.append({"uid":"draft:e1:2","item":"plant","hotel":0,"room":0,"x":4,"y":2,"rotation":0})
	check(inventory.quote(model,0,0,free_draft).cost_coins == 0, "Starter licenses create free copies")
	var fixture_draft := current.duplicate(true); fixture_draft.append({"uid":"draft:e1:3","item":"room_nightstand","hotel":0,"room":0,"x":5,"y":2,"rotation":0})
	check(not inventory.quote(model,0,0,fixture_draft).ok, "Included fixtures cannot be minted")
	var fake := current.duplicate(true); fake.append({"uid":"f999","item":"plant","hotel":0,"room":0,"x":4,"y":2,"rotation":0})
	check(not inventory.quote(model,0,0,fake).ok, "Fabricated permanent UIDs reject")
	var borrowed := current.duplicate(true); borrowed.append(inventory.room_items(0,1)[0].duplicate(true)); borrowed.back().x=4; borrowed.back().y=2
	check(not inventory.quote(model,0,0,borrowed).ok, "A placed item cannot be borrowed from another room")
	var blanket := current.duplicate(true); blanket.remove_at(0); blanket.append({"uid":"draft:e1:4","item":"blanket","hotel":0,"room":0,"x":0,"y":0,"rotation":0})
	check(inventory.quote(model,0,0,blanket).code == "locked", "Bond furniture cannot be minted before its reuse license is earned")
	model.coins_units = 0
	var unaffordable := inventory.quote(model,0,0,draft)
	check(not unaffordable.ok and unaffordable.code == "unaffordable" and unaffordable.cost_coins == 140 and unaffordable.purchases == ["scratch"] and unaffordable.report.quality > 0, "An unaffordable valid quote retains its price, purchases, and report")

func test_apply_is_atomic_and_idempotent() -> void:
	var model := FakeModel.new(); var inventory := Inventory.new(); inventory.ensure_rooms(model,0)
	var draft := inventory.room_items(0,0); draft.append({"uid":"draft:e2:1","item":"scratch","hotel":0,"room":0,"x":4,"y":2,"rotation":0})
	var edit := {"hotel":0,"room":0,"edit_id":"e2","base_room_revision":0,"base_inventory_revision":inventory.state.revision,"cost_coins":140,"instances":draft}
	var before_units: int = model.coins_units
	var result := inventory.apply(model,edit)
	check(result.ok and model.coins_units == before_units - 140 * model.UNIT, "Apply debits exactly once")
	check(inventory.room_record(0,0).revision == 1 and inventory.state.revision == edit.base_inventory_revision + 1, "Apply advances room and inventory revisions")
	check(not str(find_item(inventory.room_items(0,0),"scratch").uid).begins_with("draft:"), "Apply allocates a stable permanent UID")
	var serialized := inventory.serialize(); var units := model.coins_units
	var retry := inventory.apply(model,edit)
	check(retry.ok and retry.already_applied and inventory.serialize() == serialized and model.coins_units == units, "An edit receipt makes retries idempotent")
	var stale := edit.duplicate(true); stale.edit_id="e3"; stale.base_room_revision=0
	check(not inventory.apply(model,stale).ok and inventory.serialize() == serialized and model.coins_units == units, "A stale apply rejects atomically")
	var wrong_price := edit.duplicate(true); wrong_price.edit_id="e4"; wrong_price.base_room_revision=1; wrong_price.base_inventory_revision=inventory.state.revision; wrong_price.cost_coins=0
	check(inventory.apply(model,wrong_price).code == "price_changed" and inventory.serialize() == serialized and model.coins_units == units, "Apply does not trust a stale quoted price")
