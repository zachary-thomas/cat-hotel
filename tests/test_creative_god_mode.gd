extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var model=Model.new(); model.new_game(1000)
	if not model.has_method("set_god_mode"):
		check(false,"Settings needs a persistent God mode with free editing and all unlocks")
		quit(1); return
	check(not model.is_god_mode(),"Fresh games start with normal gameplay")
	model.state.coins=0
	var before: Dictionary=model.serialize()
	var rejected: Callable=func(_model): return false
	check(not model.set_god_mode(true,rejected).ok and model.serialize()==before,"Failed God-mode save rolls back every unlock")
	check(model.set_god_mode(true).ok and model.is_god_mode(),"Enable God mode")
	for index in range(4):
		check(model.hotel(index).owned and model.hotel(index).plots.size()==3,"God mode unlocks map and land %d" % index)
		check(model.can_travel(index).ok and model.can_travel(index).cost==0,"Every destination is immediately available")
	for cat in model.state.cats: check(cat.known,"Every cat is unlocked")
	check(model.commit("hire_housekeeper",{}).ok,"Housekeeping is available at starter level")
	check(model.commit("upgrade",{"service":0}).ok and model.commit("train",{"staff":0}).ok,"Services and staff can be upgraded for free")
	check(model.catalog_price("place_room",{"kind":"suite","w":4,"h":5})==0,"Catalog room prices reflect free building")
	check(model.catalog_price("place_template",{"template":"milkshake"})==0,"Complete arrangements show the free price")
	var payload: Dictionary={"kind":"suite","name":"Debug cottage","x":12,"y":-10,"w":4,"h":5,"rotation":0}
	check(model.quote("place_room",payload).cost==0 and model.commit("place_room",payload).ok,"A suite can be built with an empty wallet")
	var room_id: String=model.hotel().rooms[-1].id
	check(model.hotel().rooms[-1].paid==0,"Free room shells cannot create refund coins")
	check(model.commit("place_object",{"item":"blanket","x":12.5,"y":-9.5,"rotation":0}).ok,"Friendship item restrictions are bypassed")
	check(model.commit("resize_room",{"id":room_id,"w":6,"h":5}).ok,"Growing a room is free")
	check(model.commit("paint_path",{"style":"brick","cells":[[18,-7],[18,-6]]}).ok,"Expensive paths are free")
	check(model.hotel().paths["18,-7"].paid==0,"Free paths carry no paid refund value")
	check(model.state.coins==0,"Debug editing never debits or credits the wallet")
	var stable: Dictionary=model.serialize()
	check(not model.commit("place_room",payload).ok and model.serialize()==stable,"God mode preserves overlap and placement validation")
	check(model.undo().ok and model.redo().ok and model.state.coins==0,"Undo and Redo work for free edits")
	var reopened=Model.new()
	check(reopened.restore(model.serialize()) and reopened.is_god_mode(),"God mode and all edited geometry survive reopening")
	check(reopened.set_god_mode(false).ok and not reopened.is_god_mode(),"God mode can be switched off")
	check(reopened.hotel().rooms.size()==model.hotel().rooms.size() and reopened.hotel(3).owned,"Switching off keeps creations and unlocked content")
	check(not reopened.undo().ok,"Mode changes start a fresh Undo history")
	check(reopened.catalog_price("place_object",{"item":"bench"})==90,"Normal catalog prices return")
	check(not reopened.commit("place_object",{"item":"bench","x":16,"y":7,"rotation":0}).ok,"Normal insufficient-funds checks return")
	check(reopened.commit("remove_room",{"id":room_id}).ok and reopened.state.coins==0,"A free room yields no refund after disabling God mode")
	check(reopened.commit("erase_path",{"cells":[[18,-7],[18,-6]]}).ok and reopened.state.coins==0,"Free paths yield no refund after disabling God mode")
	var old=Model.new(); old.new_game(1000)
	var old_save: Dictionary=old.serialize(); old_save.settings.erase("god_mode")
	check(reopened.restore(old_save) and not reopened.is_god_mode(),"Existing creative saves default to normal mode")
	old_save.settings.god_mode="enabled"
	check(not reopened.restore(old_save),"Invalid God-mode settings are rejected safely")
	print("CREATIVE GOD MODE: %d failures" % failures)
	quit(1 if failures else 0)
