extends SceneTree
const Model = preload("res://scripts/core/hotel_model.gd")
const Quality = preload("res://scripts/core/room_quality.gd")
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures += 1; push_error(message)
func _initialize() -> void:
	var model = Model.new(); model.new_game(1000)
	check(model.serialize().version == 3,"New games use furniture save version 3")
	if model.serialize().version != 3: quit(1); return
	check(model.furniture.room_items(0,0).size() == 4,"Starter room includes its four owned objects")
	check(not model.life.serialize().has("furniture") and not model.life.serialize().hotels[0].has("rooms"),"Legacy ownership has one authority")
	var before := JSON.stringify(model.serialize())
	var bad: Dictionary = model.serialize(); bad.furniture.instances[0].item = "missing"
	check(not model.restore(bad),"Reject corrupt furniture")
	check(JSON.stringify(model.serialize()) == before,"Restore is atomic")
	var copy = Model.new(); check(copy.restore(model.serialize()),"Version 3 round trip")
	check(copy.rate() == model.rate(),"Income survives round trip")
	for version in [1,2]:
		var legacy = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/legacy_build_v%d.json" % version))
		check(copy.restore(legacy),"Real legacy save migrates")
		check(copy.coins_units == int(legacy.coins_units) and copy.pending_units == int(legacy.pending_units),"Migration preserves wallet and offline envelope")
		check(copy.furniture.room_items(0,0).size() >= 4,"Migration owns included fixtures")
		check(copy.restore(copy.serialize()),"Migrated save reloads")
	model.life.bond(0,20,0)
	check(model.furniture.state.legacy_reuse.has("blanket"),"Friendship grants reusable blanket recipe")
	check(not model.life.perform(model,"furnish",{"room":0,"item":"heated"}).ok,"Old purchase path cannot bypass Build Apply")
	print("Build transactions: %d failures" % failures); quit(1 if failures else 0)
