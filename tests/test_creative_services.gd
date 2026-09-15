extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var model=Model.new(); model.new_game(1000)
	var data: Dictionary=model.hotel()
	data.rooms=[{"id":"counter-room","kind":"shared","name":"Facing counters","x":-5,"y":-5,"w":10,"h":10,"rotation":0,"paid":0}]
	data.objects=[]; data.paths.clear()
	for x in range(-12,12):
		for y in range(-12,12): data.paths["%d,%d" % [x,y]]={"style":"earth","paid":0}
	for counter in [["first",0.0,0.0,0],["second",0.0,-1.5,2]]:
		data.objects.append({"id":counter[0],"item":"milkshake_counter","room":"counter-room","x":counter[1],"y":counter[2],"rotation":counter[3],"paid":0})
	model._invalidate()
	var reserved: Dictionary={}
	for venue in model.venues():
		if not venue.open: continue
		check(venue.has("staff_slot"),"Every open bar has a serving position")
		check(not reserved.has(venue.staff_slot.key),"Facing counters never reserve the same attendant position")
		reserved[venue.staff_slot.key]=true
	for venue in model.venues():
		for slot in venue.slots: check(not reserved.has(slot.key),"Guests cannot use any counter's staff position")
	model.advance(1)
	var positions: Dictionary={}
	for actor in model.social.agents.values():
		if actor.slot=="": continue
		check(not positions.has(actor.slot),"Every actor retains its own physical reservation")
		positions[actor.slot]=true
	var rate_before: float=model.rate()
	data.objects.erase(data.objects[-1]); model._invalidate()
	check(is_equal_approx(model.rate(),rate_before),"Multiple milkshake bars add capacity without multiplying upgrade income")
	model.new_game(1000); model.state.coins=10000
	var bedroom: Dictionary=model.hotel().rooms[0]
	for object in model.hotel().objects:
		if object.room==bedroom.id and object.item=="mat": object.item="sun_cushion"
	model.hotel().objects.append({"id":"bonus-perch","item":"perch","room":bedroom.id,"x":-6.5,"y":-5.5,"rotation":0,"paid":0})
	model._invalidate()
	check(model.room_status(bedroom.id).get("bonus",0)==8,"Ready guest room earns its existing furnishing-combination bonus")
	for object in model.hotel().objects.duplicate():
		if object.room==bedroom.id and object.item=="sun_cushion": model.hotel().objects.erase(object)
	model._invalidate()
	check(not model.room_status(bedroom.id).ready and model.room_status(bedroom.id).get("bonus",0)==0,"Unfinished bedroom contributes no room bonus")
	check(model.guest_capacity()==2,"Only the remaining ready room contributes guest capacity")
	model.new_game(1000)
	check(model.commit("place_object",{"item":"bench","x":5,"y":-4,"rotation":0}).ok,"Place a garden bench directly on owned grass")
	var bench_id: String=model.hotel().objects[-1].id
	var bench_open:=false
	for venue in model.venues():
		if venue.id==bench_id: bench_open=venue.open
	check(bench_open,"Outdoor seating accepts grass access without forcing a constructed path")
	model.new_game(1000)
	var reception: Dictionary={}
	for object in model.hotel().objects:
		if object.item=="reception_counter": reception=object.duplicate(); break
	check(model.commit("store_object",{"id":reception.id}).ok,"Reception can be stored while building")
	check(model.guest_capacity()==0,"Removing reception makes guest rooms unavailable")
	check(model.commit("retrieve_object",{"id":reception.id,"x":-0.5,"y":5,"rotation":0}).ok,"Reception can reopen at a new position")
	check(model.guest_capacity()==4,"Room readiness follows the moved working reception")
	model.advance(0.1)
	var guest: Dictionary=model.social.agents.get(0,{})
	check(guest.get("venue","")==reception.id and float(guest.destination.y)>=4.5,"A fresh arrival targets the new reception position")
	print("CREATIVE SERVICES: %d failures" % failures)
	quit(1 if failures else 0)
