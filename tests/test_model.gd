extends SceneTree

var failures: int = 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var script = load("res://scripts/core/hotel_model.gd")
	if script == null:
		push_error("Hotel model is not implemented")
		quit(1)
		return
	var m = script.new()
	m.new_game(1000)
	m.hotels[0].zones = [3, 3, 3, 3]
	m.advance(60.0)
	check(is_equal_approx(m.coins, 1120.0), "One minute at 120/min earns 120")
	check(m.upgrade(0, 0), "Affordable upgrade succeeds")
	check(is_equal_approx(m.coins, 640.0), "Level 3 to 4 deducts 480 exactly once")
	check(m.rate() == 130, "Upgrade increases network rate by 10")
	m.coins = 0
	check(not m.upgrade(0, 0) and m.hotels[0].zones[0] == 4, "Insufficient funds cannot change level")
	check(not m.unlock_hotel(1), "Hotel gate rejects early unlock")
	m.hotels[0].purchases = 18
	m.coins = 10000
	check(m.hotel_level(0) == 10 and m.unlock_hotel(1), "Level and funds unlock Seaside")
	check(m.coins == 0 and m.rate() == 140, "New hotel adds income without resetting old one")
	check(not m.unlock_hotel(1), "An owned hotel cannot charge twice")
	m.new_game(1000)
	m.hotels[0].zones = [3, 3, 3, 3]
	m.reconcile(8200)
	check(is_equal_approx(m.pending_coins, 14400.0), "Two hours produces 14,400 offline coins")
	check(m.claim() == 14400, "Claim returns reward")
	check(m.claim() == 0 and m.coins == 15400, "Repeated claim cannot pay twice")
	m.new_game(1000)
	m.hotels[0].zones = [3, 3, 3, 3]
	m.reconcile(37000)
	check(m.pending_coins == 57600 and m.pending_seconds == 28800, "Ten hours caps at eight")
	m.reconcile(40600)
	check(m.pending_coins == 57600, "Reopening cannot reset pending cap")
	m.new_game(1000)
	m.hotels[0].zones = [3, 3, 3, 3]
	m.reconcile(15400)
	m.hotels[0].zones[0] = 4
	m.reconcile(29800)
	check(m.pending_coins == 60000, "Each offline segment retains its own rate")
	m.reconcile(900)
	check(m.last_seen == 29800 and m.pending_coins == 60000, "Clock rollback grants no duplicate time")
	m.new_game(1000)
	for i in range(600):
		m.advance(0.1)
	check(is_equal_approx(m.coins, 1010), "Fractional frames preserve whole-minute income")
	var restored = script.new()
	check(restored.restore(m.serialize()), "Serialized state restores")
	check(is_equal_approx(restored.coins, m.coins), "Round-trip preserves currency")
	check(not restored.restore({"version": 999}), "Unsupported saves rejected")
	var corrupt: Dictionary = m.serialize()
	corrupt["coins_units"] = -10
	check(not restored.restore(corrupt), "Negative balance save rejected")
	m.new_game(1000)
	m.coins = 20000
	check(not m.expand(0) and m.room_count(0) == 2, "A funded wing still requires the hotel level gate")
	m.hotels[0].purchases = 2
	m.coins = 1199
	check(not m.expand(0) and m.coins == 1199, "An unaffordable wing cannot debit coins")
	m.coins = 1200
	check(m.expand(0) and m.coins == 0 and m.room_count(0) == 2 and m.wing_count(0)==1, "First wing unlocks building space for exactly 1200 without placing rooms")
	check(m.hotel_rate(0) == 40 and m.discovered_cats() == 6, "Rooms earn income and introduce guests")
	m.reconcile(4600)
	check(m.pending_coins == 2400, "Wing income participates in offline accrual")
	check(restored.restore(m.serialize()) and restored.wing_count(0) == 1, "Expanded hotel survives a save round-trip")
	m.coins = 20000
	m.hotels[0].purchases = 10
	check(m.expand(0) and m.expand(0), "Further level gates permit the next two wings")
	var full_balance: float = m.coins
	check(not m.expand(0) and m.coins == full_balance and m.room_count(0) == 2, "A fully expanded hotel cannot charge for a fourth wing or auto-place rooms")
	check(not m.expand(1) and not m.expand(-1) and not m.expand(12), "Unowned and invalid hotels cannot expand")
	check(m.hotel_rate(0) == 170, "All three wing rates accumulate")
	var legacy: Dictionary = m.serialize()
	for hotel in legacy.hotels:
		hotel.erase("wings")
		hotel.erase("layout")
	legacy.settings.erase("music")
	legacy.settings.erase("evening")
	legacy.settings.sound = false
	check(restored.restore(legacy) and restored.room_count(0) == 2 and not restored.settings.music, "Older saves migrate without losing their mute preference")
	for bad_wings in [-1, 4, 1.5, "two"]:
		corrupt = m.serialize()
		corrupt.hotels[0].wings = bad_wings
		check(not restored.restore(corrupt), "Invalid expansion data is rejected")
	m.new_game(1000)
	m.coins = 1200
	check(not m.start_repair(0), "Repairs retain the hotel level requirement")
	m.hotels[0].purchases = 2
	check(m.start_repair(0) and m.coins == 0, "A repair charges its price exactly once")
	check(not m.start_repair(0) and m.room_count(0) == 2, "A second tap cannot duplicate an active repair or open rooms early")
	m.advance(10)
	check(is_equal_approx(m.repair_remaining(0),20) and m.hotel_rate(0) == 10, "Builders work while unopened rooms earn no income")
	check(restored.restore(m.serialize()) and is_equal_approx(restored.repair_remaining(0),20), "Partial repair progress survives saving")
	restored.advance(20)
	check(restored.wing_count(0) == 1 and restored.repair_remaining(0) == 0 and restored.hotel_rate(0) == 40, "Construction completes at its exact deadline")
	m.new_game(1000)
	m.coins = 1200
	m.hotels[0].purchases = 2
	m.start_repair(0)
	m.reconcile(1060)
	check(m.wing_count(0) == 1 and is_equal_approx(m.pending_coins,25) and m.coins == 0, "Offline earnings change only after the repair completes and remain unclaimed")
	m.reconcile(1060)
	check(m.wing_count(0) == 1 and is_equal_approx(m.pending_coins,25), "Reopening cannot finish or credit the same repair twice")
	m.coins = 3500
	m.hotels[0].purchases = 6
	m.pending_seconds = m.OFFLINE_CAP
	m.away_seconds = m.OFFLINE_CAP
	check(m.start_repair(0), "The next wing can be repaired after the first finishes")
	m.reconcile(1180)
	check(m.wing_count(0) == 2 and is_equal_approx(m.pending_coins,25), "Repairs continue even when offline income is capped")
	for bad_time in [-1, INF, NAN, "30", 91]:
		corrupt = m.serialize()
		corrupt.hotels[0].repair_remaining = bad_time
		check(not restored.restore(corrupt), "Invalid repair timers are rejected")
	corrupt = m.serialize()
	corrupt.hotels[0].wings = 3
	corrupt.hotels[0].repair_remaining = 1
	check(not restored.restore(corrupt), "A full hotel cannot load a fourth repair")
	print("MODEL TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
