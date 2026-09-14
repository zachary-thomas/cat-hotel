extends SceneTree

const Model = preload("res://scripts/core/hotel_model.gd")
const Layout = preload("res://scripts/core/room_layout.gd")
var failures: int = 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)

func room(x: int, y: int, rotation: int = 0, kind: String = "regular") -> Dictionary:
	return {"kind":kind, "x":x, "y":y, "rotation":rotation}

func _initialize() -> void:
	var model = Model.new()
	model.new_game(1000)
	check(model.room_count(0) == 2 and model.hotels[0].has("layout"), "New games contain two saved starter rooms")
	check(Layout.valid_saved(model.hotels[0].layout, 0), "Starter entrances connect to the lobby")
	check(Layout.dimensions("regular", 1) == Vector2i(3, 4) and Layout.dimensions("suite", 3) == Vector2i(5, 4), "Rotations swap both room footprints")
	check(Layout.door_cell(room(0, 9)) == Vector2i(4, 10), "East entrance is centered beside the regular room")
	check(Layout.door_cell(room(6, 9, 2)) == Vector2i(5, 10), "West entrance faces the central corridor")
	var snapshot: Dictionary = model.serialize()
	check(not Layout.validate(model, 0, room(0, 6)).ok, "Locked floor cannot accept a room")
	check(not Layout.validate(model, 0, room(-1, 9)).ok, "Rooms cannot extend beyond the floor")
	check(not Layout.validate(model, 0, room(0, 9)).ok, "Overlapping rooms are rejected")
	check(not Layout.validate(model, 0, room(0, 9, 2), 0).ok, "A moved entrance cannot face a sealed exterior wall")
	check(not Layout.validate(model, 0, room(0, 9, 0, "suite"), 0).ok, "Move cannot turn a regular room into a free suite")
	check(model.serialize() == snapshot, "Placement previews never change the save or wallet")
	check(not Layout.perform(model, "move_room", room(0, 9)).ok and model.serialize() == snapshot, "Missing move index cannot buy or change a room")
	model.hotels[0].purchases = 2
	model.coins = 1200
	check(model.expand(0) and model.room_count(0) == 2, "Restoring a wing unlocks empty floor without free rooms")
	check(Layout.validate(model, 0, room(0, 6)).ok, "Newly unlocked floor accepts a room")
	snapshot = model.serialize()
	check(not Layout.perform(model, "place_room", room(0, 6)).ok and snapshot == model.serialize(), "Unaffordable builds leave all saved state untouched")
	model.coins = 450
	var old_rate: int = model.rate()
	var placed: Dictionary = Layout.perform(model, "place_room", room(0, 6))
	check(placed.ok and placed.room == 2 and model.room_count(0) == 3 and model.coins == 0, "A regular room costs exactly450 and keeps stable furniture indices")
	check(model.hotels[0].purchases == 3 and model.rate() == old_rate + 12, "Room purchases add progression and twelve coins per minute")
	var move: Dictionary = room(6, 6, 2)
	move.room = 2
	check(Layout.perform(model, "move_room", move).ok and model.coins == 0 and model.hotels[0].purchases == 3, "Moving costs nothing and preserves purchase progression")
	snapshot = model.serialize()
	move = room(0, 9)
	move.room = 2
	check(not Layout.perform(model, "move_room", move).ok and model.serialize() == snapshot, "Rejected moves preserve the wallet, layout and furnishing state")
	check(not model.furniture.room_items(0,2).is_empty() and model.furniture.room_record(0,2).revision > 0, "Layout initializes authoritative furniture and moving increments its room revision")
	var route: Array[Vector2] = Layout.route(model, 0, 2)
	var target: Vector3 = Layout.center(model.hotels[0].layout[2])
	check(route.size() >= 3 and route.back().is_equal_approx(Vector2(target.x, target.z)), "Guest paths travel from the lobby to the moved room center")
	check(route.front().y > Layout.ORIGIN.y + Layout.GRID_HEIGHT * Layout.CELL_SIZE, "Guest route starts outside the southern lobby boundary")
	model.hotels[0].layout = [room(0, 6), room(6, 6, 2)]
	check(not Layout.validate(model, 0, room(3, 9)).ok, "A room cannot disconnect otherwise empty entrances from the lobby")
	# Begin the suite case from a consistent authoritative inventory; the earlier
	# overlap fixture deliberately replaced the layout array directly.
	model.new_game(1000)
	model.hotels[0].wings = 2
	model.coins = 1200
	old_rate = model.rate()
	check(Layout.perform(model, "place_room", room(0, 4, 0, "suite")).ok and model.coins == 0 and model.rate() == old_rate + 28, "Suites use their larger footprint and cost1200 for28 income")
	move = room(0, 4, 1, "suite")
	move.room = 2
	check(Layout.perform(model, "move_room", move).ok, "A rotated suite can move while keeping its south entrance connected")
	check(not Layout.validate(model, 0, room(3, 3, 1)).ok, "Rotated footprint detects overlap with a suite")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.serialize()))
	var restored = Model.new()
	check(restored.restore(saved) and restored.hotels[0].layout == model.hotels[0].layout, "JSON number conversion preserves exact room layouts")
	snapshot = restored.serialize()
	for bad_value in [-1, 4, 0.5, "1", true, INF, NAN]:
		var corrupt: Dictionary = model.serialize()
		corrupt.hotels[0].layout[0].rotation = bad_value
		check(not restored.restore(corrupt) and restored.serialize() == snapshot, "Invalid room rotations reject restore atomically")
	for bad_layout in [[], [room(0, 9)], [room(0, 9), room(0, 9)], [room(0, 0), room(6, 0, 2)], "rooms"]:
		var corrupt: Dictionary = model.serialize()
		corrupt.hotels[0].layout = bad_layout
		check(not restored.restore(corrupt), "Malformed, overlapping or locked saved layouts are rejected")
	for bad_value in [0.25, true, "0", INF, NAN]:
		var corrupt: Dictionary = model.serialize()
		corrupt.hotels[0].layout[0].x = bad_value
		check(not restored.restore(corrupt), "Saved coordinates must be finite whole JSON numbers")
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_build_v2.json"))
	for hotel in legacy.hotels:
		hotel.erase("layout")
	check(restored.restore(legacy) and restored.room_count(0) == 8, "Legacy saves migrate all restored wings without losing rooms")
	check(restored.hotels[0].layout[6] == room(0, 0) and restored.hotels[0].layout[7] == room(6, 0, 2), "Migration retains old left/right furniture index order")
	check(Layout.valid_saved(restored.hotels[0].layout, 3), "The full eight-room migration has reachable entrances")
	check(not Layout.validate(restored, 0, room(4, 0)).ok, "The eight-room capacity cannot be exceeded")
	restored.coins = 10000
	snapshot = restored.serialize()
	check(not Layout.perform(restored, "place_room", room(4, 0)).ok and restored.serialize() == snapshot, "A funded ninth-room attempt cannot debit or alter the full hotel")
	model.new_game(1000)
	model.coins = 1200
	model.hotels[0].purchases = 2
	check(model.start_repair(0), "Construction can begin with starter layout")
	model.advance(30)
	check(model.wing_count(0) == 1 and model.room_count(0) == 2, "Timed expansion also opens empty floor")
	print("LAYOUT TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
