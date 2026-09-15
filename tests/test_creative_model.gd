extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	if not FileAccess.file_exists("res://scripts/creative/creative_model.gd"):
		check(false,"Creative building model must support owned plots and unfinished rooms")
		quit(1)
		return
	var script = load("res://scripts/creative/creative_model.gd")
	var model = script.new()
	model.new_game(1000)
	check(model.hotel().rooms.size() >= 2,"A fresh hotel starts with guest rooms")
	check(model.state.coins == 1000,"Fresh wallet starts at 1000")
	var snapshot = model.serialize()
	var quote = model.quote("buy_plot",{"id":"east"})
	check(quote.ok and quote.cost==750,"East expansion quotes the real earned-coin cost")
	check(model.serialize()==snapshot,"Quoting cannot change the save")
	check(model.commit("buy_plot",{"id":"east"}).ok,"Buy east land")
	check(model.state.coins==250 and model.hotel().plots.has("east"),"Land ownership and debit are committed together")
	check(not model.commit("buy_plot",{"id":"east"}).ok,"Cannot pay twice for land")
	model.advance(10)
	var earned = model.state.coins
	check(model.undo().ok,"Undo a land purchase")
	check(is_equal_approx(model.state.coins,earned+750),"Undo retains earned income")
	check(model.redo().ok,"Redo restores the same purchase")
	var before = model.serialize()
	model.state.coins=10000
	before=model.serialize()
	var broken: Callable=func(_model): return false
	check(not model.commit("buy_plot",{"id":"west"},broken).ok,"Save failure rejects the commit")
	check(model.serialize()==before,"Failed save restores ownership and wallet")
	var restored=script.new()
	check(restored.restore(model.serialize()),"New preview save round trip")
	check(restored.hotel().plots.has("east"),"Purchased land survives reopening")
	print("CREATIVE MODEL: %d failures" % failures)
	quit(1 if failures else 0)
