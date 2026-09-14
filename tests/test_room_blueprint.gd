extends SceneTree

const Model = preload("res://scripts/core/hotel_model.gd")
const Blueprint = preload("res://scripts/core/room_blueprint.gd")
const RoomBuilder = preload("res://scripts/world/room_builder.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func fresh(coins: int = 10000):
	var model = Model.new()
	model.new_game(1000)
	model.coins_units = coins * model.UNIT
	return model

func candidate(kind: String, x: int, y: int, rotation: int) -> Dictionary:
	return {"kind":kind,"x":x,"y":y,"rotation":rotation}

func add_scratch(model) -> void:
	var items: Array = model.furniture.room_items(0,0)
	items.append({"uid":"draft:source:1","item":"scratch","hotel":0,"room":0,"x":4,"y":2,"rotation":0})
	var record: Dictionary = model.furniture.room_record(0,0)
	var edit := {"hotel":0,"room":0,"edit_id":"source","base_room_revision":record.revision,
		"base_inventory_revision":model.furniture.state.revision,"instances":items}
	check(model.furniture.apply(model,edit).ok, "Paid source furniture can be prepared")

func layout_shape(items: Array) -> Array:
	var result: Array = []
	for value in items:
		result.append({"item":value.item,"x":value.x,"y":value.y,"rotation":value.rotation})
	result.sort_custom(func(a,b): return str(a.item) < str(b.item))
	return result

func uid_set(items: Array) -> Dictionary:
	var result := {}
	for value in items: result[value.uid] = true
	return result

func test_regular_copy_cost_and_repetition() -> void:
	var model = fresh()
	add_scratch(model)
	model.hotels[0].wings = 1
	var source_before: Array = model.furniture.room_items(0,0)
	var clipboard := Blueprint.capture(model,0,0)
	check(clipboard.version == 1 and clipboard.kind == "regular" and layout_shape(clipboard.items) == layout_shape(source_before), "Capture preserves the exact regular-room layout")
	var quote := Blueprint.quote(model,0,clipboard,candidate("regular",0,6,0))
	check(quote.ok and quote.room_cost == 450 and quote.furniture_cost == 140 and quote.cost_coins == 590, "Paste charges the full room and nonlicensed copy prices")
	var before_units: int = model.coins_units
	var first := Blueprint.place(model,0,clipboard,candidate("regular",0,6,0))
	check(first.ok and first.room == 2 and model.coins_units == before_units - 590 * model.UNIT, "First paste charges once and returns the new room")
	var first_items: Array = model.furniture.room_items(0,first.room)
	check(layout_shape(first_items) == layout_shape(source_before) and model.furniture.room_items(0,0) == source_before, "Paste keeps source unchanged and reproduces the layout")
	check(first_items.size() == clipboard.items.size() and first_items.filter(func(v): return v.item == "room_nightstand").size() == 1, "Paste replaces starter grants without storing extras")
	var first_uids := uid_set(first_items)
	var second := Blueprint.place(model,0,clipboard,candidate("regular",6,6,2))
	check(second.ok and model.coins_units == before_units - 1180 * model.UNIT, "Repeated paste charges each new copy")
	var second_items: Array = model.furniture.room_items(0,second.room)
	for uid in uid_set(second_items): check(not first_uids.has(uid), "Repeated paste allocates distinct UIDs")
	check(model.furniture.stored_items().is_empty(), "Blueprint paste never consumes or creates storage")

func test_licensed_free_and_rotated_suite() -> void:
	var model = fresh()
	model.furniture.state.legacy_reuse.append("scratch")
	add_scratch(model)
	model.hotels[0].wings = 2
	var free_clipboard := Blueprint.capture(model,0,0)
	check(Blueprint.quote(model,0,free_clipboard,candidate("regular",0,6,0)).furniture_cost == 0, "Legacy reuse copies are free")
	var suite_source := Blueprint.place(model,0,{"version":1,"kind":"suite","name":"Suite blueprint","items":[
		{"item":"mat","x":0,"y":0,"rotation":0},{"item":"box","x":4,"y":0,"rotation":0},{"item":"plant","x":7,"y":0,"rotation":0},
		{"item":"room_nightstand","x":3,"y":0,"rotation":0},{"item":"suite_sofa","x":0,"y":7,"rotation":0},{"item":"suite_table","x":4,"y":7,"rotation":0}]},candidate("suite",0,4,1))
	check(suite_source.ok, "A rotated suite blueprint places legally")
	var suite_clipboard := Blueprint.capture(model,0,suite_source.room)
	check(suite_clipboard.kind == "suite" and suite_clipboard.items.size() == 6, "Suite capture includes its exact fixtures")
	var restored = Model.new()
	check(restored.restore(model.serialize()), "Blueprint result remains valid through model restore")

func test_rejections_rollback_everything() -> void:
	var model = fresh()
	add_scratch(model)
	var clipboard := Blueprint.capture(model,0,0)
	var cases := [
		{"label":"locked floor","coins":10000,"wings":0,"candidate":candidate("regular",0,6,0),"blueprint":clipboard},
		{"label":"overlap","coins":10000,"wings":1,"candidate":candidate("regular",0,9,0),"blueprint":clipboard},
		{"label":"insufficient funds","coins":589,"wings":1,"candidate":candidate("regular",0,6,0),"blueprint":clipboard},
	]
	for data in cases:
		model.hotels[0].wings = data.wings
		model.coins_units = data.coins * model.UNIT
		model.life.notices = [{"message":"keep me"}]
		var before := model.serialize()
		var notices: Array = model.life.notices.duplicate(true)
		var result := Blueprint.place(model,0,data.blueprint,data.candidate)
		check(not result.ok and model.serialize() == before and model.life.notices == notices, data.label + " rejects with full rollback")
	var forged := clipboard.duplicate(true)
	forged.items.append({"item":"room_nightstand","x":5,"y":4,"rotation":0})
	model.hotels[0].wings = 1; model.coins_units = 10000 * model.UNIT
	var before := model.serialize()
	check(Blueprint.place(model,0,forged,candidate("regular",0,6,0)).code == "invalid_fixture" and model.serialize() == before, "Forged fixture duplication cannot mint included items")
	var locked := clipboard.duplicate(true)
	locked.items.append({"item":"adventure_tree","x":4,"y":2,"rotation":0})
	before = model.serialize()
	check(Blueprint.place(model,0,locked,candidate("regular",0,6,0)).code == "locked" and model.serialize() == before, "Level-locked copies reject atomically")

func test_shared_conflict_rejects_quote_and_preview_is_exact() -> void:
	var model = fresh()
	model.hotels[0].wings = 1
	var plant: Dictionary = model.furniture.room_items(0,0).filter(func(v): return v.item == "plant")[0]
	check(model.furniture.transfer(model,0,0,-2,plant.uid,0,12,0).ok, "Fixture prepares furniture on future room floor")
	var clipboard := Blueprint.capture(model,0,1)
	var before := model.serialize()
	var blocked := Blueprint.quote(model,0,clipboard,candidate("regular",0,6,0))
	check(not blocked.ok and blocked.code == "room_overlap" and model.serialize() == before, "Quote rejects a future shell collision with shared furniture without mutation")
	var builder = RoomBuilder.new()
	get_root().add_child(builder)
	builder.sync(model)
	var ghost_room := candidate("regular",0,6,0)
	builder.preview_blueprint(ghost_room,clipboard.items,false)
	var preview = builder.get_node_or_null("RoomBlueprintFurniturePreview")
	check(preview != null and preview.objects.size() == clipboard.items.size(), "Blueprint preview renders every copied furniture item with the shell")
	var first_preview = preview
	builder.preview_blueprint(ghost_room,clipboard.items,false)
	check(builder.get_node_or_null("RoomBlueprintFurniturePreview") == first_preview, "Unchanged pointer previews retain their rendered object cache")
	builder.clear_preview()
	check(builder.get_node_or_null("RoomBlueprintFurniturePreview") == null and builder.get_node_or_null("RoomBlueprintPlacementPreview") == null, "Clearing placement removes blueprint furniture and shell previews")
	builder.free()

func run() -> void:
	test_regular_copy_cost_and_repetition()
	test_licensed_free_and_rotated_suite()
	test_rejections_rollback_everything()
	test_shared_conflict_rejects_quote_and_preview_is_exact()
	print("ROOM BLUEPRINT TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
