extends SceneTree
## Regressions for atomic save rejection, borrowed quote data and shared inventory.
const Model = preload("res://scripts/creative/creative_model.gd")
const Content = preload("res://scripts/creative/creative_content.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func fresh():
	var model = Model.new()
	model.new_game(1789430400)
	return model

func reject(model, value: Dictionary, message: String) -> void:
	var before: Dictionary = model.serialize()
	var revision: int = model.revision
	check(not model.restore(value),message)
	check(model.serialize() == before and model.revision == revision,"Rejected save leaves the live hotel intact: " + message)

func test_quote_references() -> void:
	var model = fresh()
	var borrowed: Dictionary = model.hotel()
	var rooms: Array = borrowed.rooms
	var original: Dictionary = model.serialize()
	check(model.quote("upgrade",{"service":0}).ok,"Upgrade has a valid quote")
	check(borrowed.upgrades[0] == 1,"Quoting preserves borrowed service levels")
	check(model.quote("buy_plot",{"id":"east"}).ok,"Land has a valid quote")
	check(borrowed.plots.is_empty(),"Quoting preserves borrowed plot ownership")
	check(model.quote("remove_room",{"id":rooms[0].id}).ok,"Room removal has a valid quote")
	check(rooms.size() == 4,"Quoting preserves borrowed room arrays")
	check(model.serialize() == original,"All quotes leave wallet, room IDs and construction unchanged")
	check(not model.quote("move_room",{"id":rooms[0].id,"x":200,"y":200,"rotation":0}).ok,"Invalid placement quote fails")
	check(borrowed.rooms[0].x == -10,"Rejected quotes preserve borrowed room positions")

func test_global_inventory() -> void:
	var model = fresh()
	var ids := {}
	var count := 0
	for hotel in model.state.hotels:
		for object in hotel.objects:
			ids[object.id] = true
			count += 1
	check(ids.size() == count,"Starter furniture IDs are unique across all four hotels")
	var meadow_bed: String = model.hotel(0).objects[0].id
	var coast_bed: String = model.hotel(1).objects[0].id
	check(model.commit("store_object",{"id":meadow_bed}).ok,"Store a Meadow bed")
	model.state.current_hotel = 1
	model.hotel().owned = true
	model._invalidate()
	check(model.commit("store_object",{"id":coast_bed}).ok,"Store a different Seaside bed")
	check(model.state.storage.size() == 2 and model.state.storage[0].id != model.state.storage[1].id,"Shared storage distinguishes destination starter furniture")
	check(model.commit("retrieve_object",{"id":meadow_bed,"x":-3,"y":3,"rotation":0}).ok,"Retrieve the selected Meadow bed at Seaside")
	check(model.commit("retrieve_object",{"id":coast_bed,"x":-3,"y":6,"rotation":0}).ok,"Both independently owned beds fit the same hotel")
	check(model.state.storage.is_empty(),"Both storage instances can be retrieved")

func test_corrupted_nested_records() -> void:
	var model = fresh()
	check(model.commit("buy_plot",{"id":"east"}).ok,"Integrity fixture has history to preserve")
	var valid: Dictionary = model.serialize()
	var bad: Dictionary = valid.duplicate(true)
	bad.hotels[0].rooms[1] = 0
	reject(model,bad,"Non-dictionary room is rejected before pairwise geometry")
	bad = valid.duplicate(true); bad.hotels[0].rooms[1].erase("id")
	reject(model,bad,"A later room with no ID is rejected safely")
	bad = valid.duplicate(true); bad.hotels[0].objects[1].erase("id")
	reject(model,bad,"A later object with no ID is rejected safely")
	bad = valid.duplicate(true); bad.hotels[0].objects[1].item = "missing"
	reject(model,bad,"Unknown furniture is rejected before footprint lookup")
	bad = valid.duplicate(true); bad.hotels[0].objects[0].room = "wrong_room"
	reject(model,bad,"Saved room membership must match actual geometry")
	bad = valid.duplicate(true); bad.hotels[0].dirty = []
	reject(model,bad,"Malformed housekeeping state is rejected")
	bad = valid.duplicate(true); bad.hotels[0].dirty["guest_1"] = 2
	reject(model,bad,"Dirty-room values must be booleans")
	bad = valid.duplicate(true); bad.hotels[0].dirt_cursor = -1
	reject(model,bad,"Negative housekeeping cursors are rejected")
	bad = valid.duplicate(true); bad.hotels[0].dirt_clock = NAN
	reject(model,bad,"Non-finite housekeeping clocks are rejected")
	bad = valid.duplicate(true); bad.hotels[0].maid = "yes"
	reject(model,bad,"Housekeeping ownership must be a boolean")
	bad = valid.duplicate(true); bad.cats[0].erase("preference")
	reject(model,bad,"Missing guest preferences are rejected before simulation")
	bad = valid.duplicate(true); bad.cats[0].name = []
	reject(model,bad,"Malformed guest names are rejected")
	bad = valid.duplicate(true); bad.cats[0].friend = 99
	reject(model,bad,"Playdate references must identify a guest")
	bad = valid.duplicate(true); bad.settings.motion = "false"
	reject(model,bad,"Boolean settings cannot be strings")
	for scale in [0.9,1.6,NAN]:
		bad = valid.duplicate(true); bad.settings.ui_text_scale = scale
		reject(model,bad,"Text scale must remain finite between 100 and 150 percent")
	bad = valid.duplicate(true); bad.entitlements.append("not_a_product")
	reject(model,bad,"Unknown expansion IDs are rejected")
	bad = valid.duplicate(true); bad.hotels[0].paths["01,01"] = {"style":"earth","paid":2}
	reject(model,bad,"Noncanonical path keys cannot hide duplicated cells")
	check(model.undo().ok and model.hotel().plots.is_empty(),"Rejected saves preserve usable undo history")

func test_refund_and_id_integrity() -> void:
	var model = fresh()
	var valid: Dictionary = model.serialize()
	var bad: Dictionary = valid.duplicate(true)
	bad.hotels[0].rooms[0].paid = 1000000
	reject(model,bad,"Room refund cannot exceed its replacement shell price")
	bad = valid.duplicate(true); bad.hotels[0].objects[0].paid = 1
	reject(model,bad,"A free mat cannot carry a positive purchase price")
	bad = valid.duplicate(true); bad.hotels[0].paths.values()[0].paid = 1000000
	reject(model,bad,"Path refund cannot exceed the actual material price")
	bad = valid.duplicate(true); bad.hotels[1].objects[0].id = bad.hotels[0].objects[0].id
	reject(model,bad,"Object IDs cannot collide across destinations")
	var object: Dictionary = valid.hotels[0].objects[0].duplicate(true)
	bad = valid.duplicate(true); bad.storage.append(object)
	reject(model,bad,"A placed furniture ID cannot also occur in storage")
	bad = valid.duplicate(true); object.id = "stored_bed"; object.erase("room"); bad.storage.append(object)
	reject(model,bad,"Storage entries have a complete instance schema")
	bad = valid.duplicate(true); bad.hotels[0].objects[0].id = "object17"; bad.next_id = 17
	reject(model,bad,"Next generated ID cannot collide with a placed item")
	bad.next_id = 18
	check(model.restore(bad),"A fresh next ID restores successfully")
	check(model.commit("place_object",{"item":"shrub","x":8,"y":2,"rotation":0}).ok,"Construction continues after restoring an allocated ID")
	check(model.hotel().objects[-1].id == "object18","Construction uses the noncolliding restored sequence")

func test_valid_roundtrip_and_defaults() -> void:
	var model = fresh()
	var source: Dictionary = model.serialize()
	source.settings.ui_text_scale = 1.5
	check(model.restore(source),"Real Unix timestamps and 150 percent text restore")
	check(model.state.last_seen == 1789430400 and model.state.settings.ui_text_scale == 1.5,"Restoration retains real values")
	var legacy: Dictionary = source.duplicate(true)
	legacy.settings.clear()
	for hotel in legacy.hotels:
		for key in ["dirty","maid","dirt_clock","dirt_cursor"]: hotel.erase(key)
	var before: Dictionary = legacy.duplicate(true)
	check(model.restore(legacy),"Missing optional preview fields receive safe defaults")
	check(legacy == before,"Restore normalization never modifies the source dictionary")
	check(model.hotel().dirty is Dictionary and model.state.settings.motion is bool,"Defaults make restored simulation safe")
	model.advance(121)
	check(model.hotel().dirty.size() == 1,"Restored housekeeping works after its first timer")

func run() -> void:
	test_quote_references()
	test_global_inventory()
	test_corrupted_nested_records()
	test_refund_and_id_integrity()
	test_valid_roundtrip_and_defaults()
	print("CREATIVE SAVE INTEGRITY: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
