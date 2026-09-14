extends SceneTree
const Model = preload("res://scripts/core/hotel_model.gd")
const Content = preload("res://scripts/core/game_content.gd")
const Build = preload("res://tests/fixtures/build_actions.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func action(m, name: String, payload: Dictionary = {}) -> Dictionary:
	return m.life.perform(m,name,payload)

func _initialize() -> void:
	var m = Model.new()
	m.new_game(1000)
	check(m.hotels.size()==4 and not m.hotels[2].owned,"Expansion destinations start locked; base hotel stays free")
	check(not action(m,"interact",{"cat":12,"kind":"pet"}).ok,"Unowned DLC cats cannot be interacted with")
	check(not action(m,"invite",{"cat":17}).ok,"An invitation cannot bypass a DLC entitlement")
	check(action(m,"interact",{"cat":0,"kind":"pet"}).ok,"A discovered cat can be petted")
	var first_bond: int = m.life.state.cats[0].bond
	check(first_bond==6 and m.life.state.cats[0].preference,"A favorite interaction reveals a preference and grows friendship")
	action(m,"interact",{"cat":0,"kind":"pet"})
	check(m.life.state.cats[0].bond==first_bond,"Rapid petting cannot farm friendship")
	for i in range(4):
		m.advance(12.0)
		action(m,"interact",{"cat":0,"kind":"pet"})
	check(m.furniture.state.legacy_reuse.has("blanket"),"A friendship milestone unlocks an actual furniture recipe")
	m.coins = 5000
	check(Build.replace_trio(m,0,["sun_cushion","perch","plant"]).ok,"Complementary furnishings can be purchased and applied")
	check(m.life.state.combos.has("sunbeam"),"The sunbeam combination is discovered")
	check(m.rate()==21+Model.Quality.summarize(m.furniture.room_items(0,0)).income,"Sunbeam room adds combination, destination and quality bonuses")
	var balance: float = m.coins
	check(Build.replace_trio(m,1,["sun_cushion","box","plant"]).ok,"A second bed copy can be applied")
	check(m.coins==balance-120,"New saves buy furniture per copy")
	check(not action(m,"furnish",{"room":7,"item":"cave"}).ok,"Closed rooms cannot be decorated")
	m.life.visit(m,0,0)
	check(m.life.state.hotels[0].happy>0,"A room matching a preference creates a happy visit")
	check(m.life.known(6),"A delighted sun-loving guest introduces a compatible traveler")
	check(not action(m,"specialty",{"id":"gourmet"}).ok,"Specialties require hotel level 3")
	m.hotels[0].purchases = 4
	m.hotels[0].zones = [3,1,1,1]
	check(action(m,"specialty",{"id":"gourmet"}).ok,"Hotel level 3 enables a specialty")
	var plain_rate: int = m.rate()
	check(action(m,"train",{"staff":1}).ok,"Staff can be trained after their service opens")
	check(m.rate()==plain_rate+2,"Trained staff contribute a persistent bonus")
	check(action(m,"skill",{"staff":1,"skill":1}).ok,"Trained staff can choose a meaningful skill")
	m.life.state.cats[2].bond = 12
	check(action(m,"playdate",{"cat":0,"other":2}).ok,"Acquainted cats can have a lounge playdate")
	check(m.life.state.cats[0].friend==2 and m.life.state.cats[2].friend==0,"Friendship is stored for both cats")
	check(action(m,"event",{"id":"nap"}).ok,"A player can start a repeatable event")
	check(not action(m,"event",{"id":"nap"}).ok,"Duplicate event starts are rejected")
	check(not action(m,"event",{"id":"trail"}).ok,"A destination event cannot be started in the wrong hotel")
	m.life.advance(45,m)
	check(m.life.state.hotels[0].event.is_empty() and m.life.state.hotels[0].trophies.has("nap"),"The event completes and awards its trophy")
	check(not action(m,"event",{"id":"nap"}).ok,"Events give guests a break between gatherings")
	m.life.state.hotels[0].happy = 8
	check(action(m,"inspect").ok,"A travel critic can be invited")
	check(not action(m,"inspect").ok,"Inspections cannot be duplicated")
	m.life.advance(12,m)
	check(m.life.state.hotels[0].stars==3,"Hotel stars reflect varied accomplishments")
	check(m.life.grant_product(m,"purrington.forest_lodge"),"A recognized store product can be fulfilled")
	check(m.hotels[2].owned and m.life.known(16),"Forest DLC unlocks its hotel and Juniper")
	m.life.grant_product(m,"purrington.forest_lodge")
	check(m.life.state.entitlements.size()==1,"Repeated purchase delivery is idempotent")
	check(not m.life.grant_product(m,"unknown.product"),"Unknown products cannot grant entitlements")
	var restored = Model.new()
	var json_state: Dictionary = JSON.parse_string(JSON.stringify(m.serialize()))
	check(restored.restore(json_state),"Complete gameplay state survives JSON round-trip")
	restored.advance(70)
	check(restored.life.state.cats[0].friend==2 and restored.hotels[2].owned,"Friendships and DLC survive resumed simulation")
	check(restored.furniture.room_items(0,0).any(func(value): return value.item=="perch"),"Furniture survives reload")
	var legacy: Dictionary = m.serialize()
	legacy.version = 1
	legacy.hotels = legacy.hotels.slice(0,2)
	legacy.erase("life")
	check(restored.restore(legacy) and restored.hotels.size()==4 and not restored.hotels[2].owned,"Version 1 saves migrate without granting paid content")
	var corrupt: Dictionary = m.serialize()
	corrupt.furniture.instances[0].item = "unknown_bed"
	check(not restored.restore(corrupt),"Corrupt furniture is rejected so save recovery can fall back")
	corrupt = m.serialize()
	corrupt.life.cats[0].bond = 10000
	check(not restored.restore(corrupt),"Out-of-range friendship is rejected")
	print("LIFE TESTS: ","PASS" if failures==0 else "FAIL"," (",failures," failures)")
	quit(1 if failures else 0)
