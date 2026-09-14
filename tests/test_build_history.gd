extends SceneTree

const Model = preload("res://scripts/core/hotel_model.gd")
const History = preload("res://scripts/core/build_history.gd")
const RoomLayout = preload("res://scripts/core/room_layout.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func model() -> RefCounted:
	var value := Model.new(); value.new_game(1000)
	return value

func item_uid(model_value, room: int, item: String) -> String:
	for value in model_value.furniture.room_items(0,room):
		if value.item == item: return value.uid
	return ""

func move_plant(model_value, source: int, target: int) -> Dictionary:
	return model_value.furniture.transfer(model_value,0,source,target,item_uid(model_value,source,"plant"),5,2,0)

func buy_scratch(model_value, edit_id: String) -> Dictionary:
	var record: Dictionary = model_value.furniture.room_record(0,0)
	var draft: Array = model_value.furniture.room_items(0,0)
	draft.append({"uid":"draft:%s:0" % edit_id,"item":"scratch","hotel":0,"room":0,"x":4,"y":2,"rotation":0})
	return model_value.furniture.apply(model_value,{"hotel":0,"room":0,"edit_id":edit_id,
		"base_room_revision":record.revision,"base_inventory_revision":model_value.furniture.state.revision,"instances":draft})

func run() -> void:
	test_cross_room_transfer_is_atomic()
	test_shared_floor_transfer_uses_virtual_record()
	test_history_undo_redo_preserves_income()
	test_undo_keeps_allocator_monotonic()
	test_stale_and_unaffordable_history_rejects()
	test_history_is_bounded_and_new_edits_clear_redo()
	quit(1 if failures else 0)

func test_cross_room_transfer_is_atomic() -> void:
	var m = model(); var plant_uid := item_uid(m,0,"plant")
	var source_revision: int = m.furniture.room_record(0,0).revision
	var target_revision: int = m.furniture.room_record(0,1).revision
	var global_revision: int = m.furniture.state.revision
	var moved: Dictionary = m.furniture.transfer(m,0,0,1,plant_uid,5,2,0)
	check(moved.ok and not m.furniture.room_items(0,0).any(func(v): return v.uid == plant_uid), "Transfer removes the existing UID from its source room")
	check(m.furniture.room_items(0,1).any(func(v): return v.uid == plant_uid and v.x == 5 and v.y == 2), "Transfer places that same UID in the target room")
	check(m.furniture.room_record(0,0).revision == source_revision + 1 and m.furniture.room_record(0,1).revision == target_revision + 1 and m.furniture.state.revision == global_revision + 1, "Transfer advances both room revisions and the inventory revision")
	var before: Dictionary = m.furniture.serialize(); var coins: int = m.coins_units
	var bed_uid := item_uid(m,0,"mat")
	check(not m.furniture.transfer(m,0,0,1,bed_uid,0,0,0).ok and m.furniture.serialize() == before and m.coins_units == coins, "Transfer rejects removing the source room's last reachable bed atomically")
	check(not m.furniture.transfer(m,0,1,0,"f999999",5,2,0).ok and m.furniture.serialize() == before, "Transfer rejects a UID that is not owned by the named source")

func test_shared_floor_transfer_uses_virtual_record() -> void:
	var m = model(); var uid := item_uid(m,0,"plant")
	var moved: Dictionary = m.furniture.transfer(m,0,0,-2,uid,19,39,0)
	check(moved.ok and m.furniture.room_items(0,-2).any(func(v): return v.uid == uid), "An existing room object can move directly onto the shared floor")
	check(not m.furniture.state.rooms.any(func(v): return int(v.room) == -2), "Shared-floor revision metadata stays virtual")
	check(m.furniture.room_record(0,-2).revision == m.furniture.state.revision, "The shared floor exposes the global inventory revision")
	check(m.furniture.transfer(m,0,-2,1,uid,5,2,0).ok and item_uid(m,1,"plant") != "", "The same UID can move from shared space into another room")

func test_history_undo_redo_preserves_income() -> void:
	var m = model(); var history := History.new()
	var before_transfer := history.capture(m)
	check(move_plant(m,0,1).ok, "Cross-room action is ready for history")
	history.record(before_transfer,m,0)
	var after_transfer := history.capture(m)
	var earned: int = 37 * m.UNIT; m.coins_units += earned
	check(history.undo(m).ok and item_uid(m,0,"plant") != "" and m.coins_units == 1000 * m.UNIT + earned, "Undo restores furniture without rewinding earned income")
	check(history.redo(m).ok and item_uid(m,0,"plant") == "" and item_uid(m,1,"plant") != "" and m.coins_units == 1000 * m.UNIT + earned, "Redo reapplies the transfer without changing the wallet")
	check(history.undo_steps == 1 and history.redo_steps == 0, "Successful redo returns the step to the undo stack")
	m.hotels[0].wings = 1
	var before_room := history.capture(m)
	m.coins_units += 1000 * m.UNIT
	var built := RoomLayout.perform(m,"place_room",{"hotel":0,"kind":"regular","x":0,"y":6,"rotation":0})
	check(built.ok, "Room build is ready for mixed history")
	history.record(before_room,m,450 * m.UNIT)
	var wallet_after_build: int = m.coins_units
	check(history.undo(m).ok and m.room_count(0) == 2 and m.coins_units == wallet_after_build + 450 * m.UNIT, "Mixed history undoes a room purchase and refunds only its recorded cost")
	check(history.undo(m).ok and item_uid(m,0,"plant") != "", "A second undo crosses rooms in sequence")
	check(history.redo(m).ok and history.redo(m).ok and m.room_count(0) == 3 and m.coins_units == wallet_after_build, "Sequential redo reapplies cross-room and room-build changes in order")
	var restored_revision: int = m.furniture.room_record(0,2).revision
	check(history.undo(m).ok and history.redo(m).ok and m.furniture.room_record(0,2).revision > restored_revision, "Repeated room undo and redo keeps recreated room revisions monotonic")
	var checkpoint := history.checkpoint(); history.clear()
	check(history.undo_steps == 0 and history.redo_steps == 0, "Clear empties both history stacks")
	history.restore_checkpoint(checkpoint)
	check(history.undo_steps == 2 and history.redo_steps == 0, "A save rollback can restore internal history stacks")

func test_undo_keeps_allocator_monotonic() -> void:
	var m = model(); var history := History.new(); var before := history.capture(m)
	check(buy_scratch(m,"first").ok, "First purchase succeeds")
	var first_uid := item_uid(m,0,"scratch"); var high_water: int = m.furniture.state.next_instance
	history.record(before,m,140 * m.UNIT)
	check(history.undo(m).ok and m.furniture.state.next_instance >= high_water, "Undo never rewinds the UID allocator")
	check(buy_scratch(m,"second").ok, "A new purchase after undo succeeds")
	var second_uid := item_uid(m,0,"scratch")
	check(second_uid != first_uid and int(second_uid.substr(1)) > int(first_uid.substr(1)), "An undone UID is never reused")

func test_stale_and_unaffordable_history_rejects() -> void:
	var m = model(); var history := History.new(); var before := history.capture(m)
	check(move_plant(m,0,1).ok, "Recorded action succeeds")
	history.record(before,m,0)
	m.hotels[0].purchases += 1
	var stale_state := history.capture(m); var stale_wallet: int = m.coins_units
	check(history.undo(m).code == "stale" and history.capture(m) == stale_state and m.coins_units == stale_wallet, "Undo rejects unrelated changes to editable state without overwriting them")
	m.hotels[0].purchases -= 1
	check(history.undo(m).ok, "Undo remains available after a stale rejection is resolved")
	var purchase_before := history.capture(m)
	check(buy_scratch(m,"poor").ok, "Purchase action succeeds")
	history.record(purchase_before,m,140 * m.UNIT)
	check(history.undo(m).ok, "Purchase can be undone")
	m.coins_units = 0
	var current := history.capture(m)
	check(history.redo(m).code == "unaffordable" and history.capture(m) == current and m.coins_units == 0, "Redo rejects an unaffordable purchase atomically")

func test_history_is_bounded_and_new_edits_clear_redo() -> void:
	var m = model(); var history := History.new(); var source := 0; var target := 1
	for index in range(21):
		var before := history.capture(m)
		var x := 5 if target == 1 else 7; var y := 2 if target == 1 else 0
		check(m.furniture.transfer(m,0,source,target,item_uid(m,source,"plant"),x,y,0).ok, "Bounded history action %d succeeds" % index)
		history.record(before,m,0)
		var swap := source; source=target; target=swap
	check(history.undo_steps == 20, "History retains only the newest twenty actions")
	check(history.undo(m).ok and history.redo_steps == 1, "Undo creates a redo step")
	var before_new := history.capture(m)
	check(m.furniture.transfer(m,0,target,source,item_uid(m,target,"plant"),5 if source == 1 else 7,2 if source == 1 else 0,0).ok, "A replacement edit succeeds")
	history.record(before_new,m,0)
	check(history.redo_steps == 0, "Recording a new edit clears redo history")
