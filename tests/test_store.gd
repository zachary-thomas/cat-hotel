extends SceneTree

var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var Model = load("res://scripts/core/hotel_model.gd")
	var Store = load("res://scripts/core/game_store.gd")
	var key: String = "res://tmp/test-save-" + str(Time.get_ticks_usec())
	var store = Store.new(key)
	var model = Model.new()
	model.new_game(1000)
	check(store.save_model(model), "Initial save writes")
	model.upgrade(0, 0)
	check(store.save_model(model), "Second slot commits purchase")
	var other = Model.new()
	check(store.load_model(other, 1000), "Newest valid state loads")
	check(other.coins == 698 and other.rate() == 20, "Purchase survives reload")
	other.reconcile(8200)
	check(store.save_model(other), "Pending offline reward persists")
	var reward: int = other.claim()
	check(store.save_model(other), "Claim commits")
	check(store.load_model(model, 8200), "Claimed state loads")
	check(model.claim() == 0 and model.coins == 698 + reward, "Claim cannot repeat after reload")
	var broken_slot: String = key + ".0.json"
	var broken = FileAccess.open(broken_slot, FileAccess.WRITE)
	broken.store_string("invalid")
	broken.close()
	check(store.load_model(model, 8200), "Corrupt newest slot falls back to valid backup")
	check(model.pending_coins > 0, "Backup contains the preceding valid transaction state")
	var bad_store = Store.new("res://tmp/nonexistent-parent/test-save")
	check(not bad_store.save_model(model), "Save failure is reported")
	for suffix in [".0.json", ".1.json", ".0.json.tmp", ".1.json.tmp"]:
		if FileAccess.file_exists(key + suffix):
			DirAccess.remove_absolute(key + suffix)
	print("STORE TESTS: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
