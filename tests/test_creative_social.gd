extends SceneTree
var failures: int = 0

class TestHotel extends RefCounted:
	var state: Dictionary = {"current_hotel":0,"cats":[{"id":0,"name":"Miso","known":true,"preference":"food"}]}
	var revision: int = 0
	var completed: Array = []
	var reachable: bool = true
	var property: Dictionary = {"maid":false,"dirty":true}
	var cleaned: int = 0
	var offered: Array = [
		{"id":"shake","item":"milkshake_bar","role":"bar","name":"Milkshake bar","x":2.0,"y":0.0,"tags":["food","social"],"open":true,"capacity":1,"slots":[{"key":"shake:0","x":2.0,"y":0.0,"action":"order"}]},
		{"id":"seat","item":"chair","role":"seat","name":"Chair","x":4.0,"y":0.0,"tags":["social"],"open":true,"capacity":1,"slots":[{"key":"seat:0","x":4.0,"y":0.0,"action":"sit"}]}
	]
	func map_definition() -> Dictionary: return {"arrival":[0,0]}
	func venues() -> Array:
		return offered+[{"id":"desk","item":"reception_counter","role":"reception","room":"lobby","x":0,"y":0,"tags":["social"],"open":true,"slots":[{"key":"desk:0","x":0,"y":0,"action":"greet"},{"key":"desk:1","x":0,"y":1,"action":"greet"}]}]
	func route(from: Vector2, to: Vector2, _constructed: bool = true) -> Array:
		return [from,to] if reachable else []
	func finish_visit(cat: int, tags: Array) -> void: completed.append({"cat":cat,"tags":tags})
	func hotel() -> Dictionary: return property
	func housekeeping_targets() -> Array:
		return [{"id":"cottage","x":3,"y":2}] if property.dirty else []
	func clean_room(_id: String) -> void:
		property.dirty=false
		cleaned += 1

class CapacityHotel extends TestHotel:
	var guest_limit: int = 1
	func guest_capacity() -> int: return guest_limit

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	if not FileAccess.file_exists("res://scripts/creative/social_simulation.gd"):
		check(false,"Social guests must reserve real venues and complete service cycles")
		quit(1)
		return
	var script = load("res://scripts/creative/social_simulation.gd")
	var hotel = TestHotel.new()
	var sim = script.new()
	sim.model = hotel
	var seen: Dictionary = {}
	var checked_in_first: bool = false
	for _step in range(600):
		sim.advance(0.1)
		if sim.agents.has(0): seen[sim.agents[0].phase] = true
		if sim.agents.has(0) and sim.agents[0].get("checked_in",false): checked_in_first=true
		if not hotel.completed.is_empty(): break
	check(seen.has("order") and seen.has("serve") and seen.has("sit"),"Milkshakes follow order, serve, and a reserved seat before finishing")
	check(checked_in_first,"A new arrival checks in at a real reception before taking part in activities")
	check(hotel.completed.size()==1,"One completed activity produces exactly one completed visit")
	check(hotel.completed[0].tags.has("food") if not hotel.completed.is_empty() else false,"Service reward retains the bar's activity tags after seating")
	check(sim.reservations.is_empty(),"Finishing releases the bar and seat")
	# Edits invalidate a visit without earning its unfinished reward.
	sim.reset()
	hotel.completed.clear()
	sim.advance(0.25)
	check(not sim.reservations.is_empty(),"Selecting a reachable venue reserves a real slot")
	hotel.offered.clear()
	hotel.revision += 1
	sim.advance(8.0)
	check(sim.reservations.is_empty() and hotel.completed.is_empty(),"Removing a venue cancels its visit and releases its reservations")
	check(sim.agents[0].venue=="","Guest stops targeting removed furniture")
	# Two cats cannot occupy the same service slot.
	hotel.state.cats.append({"id":1,"name":"Clover","known":true,"preference":"quiet"})
	hotel.offered=[{"id":"bed","item":"mat","name":"Bed","role":"bed","x":2,"y":0,"tags":["quiet"],"open":true,"capacity":1,"slots":[{"key":"bed:0","x":2,"y":0,"action":"sleep"}]}]
	hotel.revision += 1
	sim.reset()
	sim.advance(7.0)
	check(sim.agents.size()==2,"Named guests each have one simulation agent")
	check(sim.reservations.size()==1,"A one-seat venue accepts one reservation")
	var active: int = 0
	for actor in sim.agents.values():
		if actor.venue=="bed": active += 1
	check(active==1,"A second guest waits or chooses another venue")
	var saw_wander: bool = false
	var wandering_reserved: bool = false
	for _step in range(40):
		sim.advance(0.1)
		for actor in sim.agents.values():
			if actor.phase=="wander":
				saw_wander=true
				if actor.slot!="" or actor.venue!="": wandering_reserved=true
	check(saw_wander and not wandering_reserved and hotel.completed.is_empty(),"A checked-in guest strolls while the bed is occupied without reserving an activity or earning a reward")
	hotel.reachable=false
	hotel.revision += 1
	sim.advance(30)
	check(hotel.completed.is_empty(),"Disconnected activities never produce visit rewards")
	# Housekeeping is a real staff walk and clean cycle; it never counts as a
	# guest visit and does not duplicate a known cat's identity.
	hotel.offered=[]
	hotel.reachable=true
	hotel.property.maid=true
	hotel.revision += 1
	sim.advance(15)
	check(sim.agents.has(1000) and hotel.cleaned==1,"Hired housekeeping reaches a dirty room and cleans it once")
	check(hotel.completed.is_empty(),"A staff cleaning action never creates a guest reward")
	# A seat in a separate building cannot satisfy a counter's seating step.
	hotel.property.maid=false
	hotel.state.cats=[{"id":0,"name":"Miso","known":true,"preference":"food"}]
	hotel.offered=[
		{"id":"shake","item":"milkshake_counter","role":"bar","room":"cafe","x":2,"y":0,"tags":["food"],"open":true,"slots":[{"key":"shake:0","x":2,"y":0,"action":"order"}]},
		{"id":"elsewhere","item":"cafe_stool","role":"seat","room":"cottage","x":2,"y":1,"tags":["quiet"],"open":true,"slots":[{"key":"elsewhere:0","x":2,"y":1,"action":"sit"}]}]
	sim.reset()
	var wrong_room: bool = false
	for _step in range(150):
		sim.advance(0.1)
		if sim.agents[0].venue=="elsewhere": wrong_room=true
	check(not wrong_room,"Milkshake guests never borrow seating in another room")
	hotel.state.cats=[]
	hotel.offered=[]
	for index in range(2):
		hotel.offered.append({"id":"bar_%d"%index,"item":"milkshake_counter","role":"bar","room":"cafe_%d"%index,"x":index*4,"y":0,"tags":["food"],"open":true,"slots":[{"key":"bar_%d:guest"%index,"x":index*4,"y":1,"action":"order"}],"staff_slot":{"key":"bar_%d:staff"%index,"x":index*4,"y":-1}})
	sim.reset()
	sim.advance(0.25)
	var bar_staff: int = 0
	var staff_names: Dictionary = {}
	for actor in sim.agents.values():
		if actor.get("role","")=="bar":
			bar_staff += 1
			staff_names[actor.name]=true
	check(bar_staff==2 and staff_names.size()==2,"Copied counters each receive a distinct automatic attendant at their own station")
	hotel.offered[1].staff_slot=hotel.offered[0].staff_slot.duplicate(true)
	sim.reset()
	sim.advance(0.25)
	bar_staff=0
	for actor in sim.agents.values():
		if actor.get("role","")=="bar": bar_staff += 1
	check(bar_staff==1 and sim.reservations.size()==1,"Facing counters cannot overwrite another attendant's physical station reservation")
	var small_hotel = CapacityHotel.new()
	small_hotel.state.cats=[
		{"id":0,"name":"Miso","known":true,"preference":"food"},
		{"id":1,"name":"Clover","known":true,"preference":"food"},
		{"id":2,"name":"Bean","known":true,"preference":"food"}]
	var small_sim = script.new()
	small_sim.model=small_hotel
	var seen_guests: Dictionary = {}
	var within_capacity: bool = true
	for _step in range(260):
		small_sim.advance(1.0)
		var guests: int = 0
		for actor in small_sim.agents.values():
			if int(actor.cat)<1000:
				guests += 1
				seen_guests[actor.cat]=true
		if guests>small_hotel.guest_limit: within_capacity=false
	check(within_capacity,"Guest population never exceeds the capacity of operational rooms")
	check(seen_guests.size()==3,"Known cats beyond current capacity rotate in after completed stays")
	small_hotel.guest_limit=0
	small_hotel.revision += 1
	small_sim.advance(0.25)
	var empty_guests: int = 0
	for actor in small_sim.agents.values():
		if int(actor.cat)<1000: empty_guests += 1
	check(empty_guests==0 and small_sim.reservations.is_empty(),"Removing all operational room capacity removes guests and releases their occupied slots")
	if FileAccess.file_exists("res://scripts/creative/creative_model.gd"):
		var real_script = load("res://scripts/creative/creative_model.gd")
		var real = real_script.new()
		real.new_game(1000)
		var used_bed: bool = false
		var served_shake: bool = false
		for hotel_index in range(4):
			real.state.current_hotel=hotel_index
			real.revision += 1
			var clean_reservations: bool = true
			var population_valid: bool = true
			for _step in range(480):
				real.advance(0.25)
				var guest_count: int = 0
				for actor in real.social.agents.values():
					if int(actor.cat)>=1000: continue
					guest_count += 1
					if actor.get("role","")=="bed" and actor.phase=="activity": used_bed=true
					if actor.phase=="sit" and actor.drink: served_shake=true
					if actor.slot!="" and real.social.reservations.get(actor.slot,-1)!=int(actor.cat): clean_reservations=false
				if guest_count>real.guest_capacity(): population_valid=false
			check(clean_reservations,"Map %d preserves exclusive reservations for every active guest" % hotel_index)
			check(population_valid,"Map %d never hosts more guests than its operational rooms support" % hotel_index)
			check(real.hotel().visits>0,"Map %d completes actual reachable guest activities" % hotel_index)
		check(used_bed,"Guests return to a real bedroom's reachable bed")
		check(served_shake,"The authored seaside café supports a real served and seated milkshake visit")
		real.new_game(1000)
		for cat in real.state.cats: cat.known=true
		real.advance(15)
		check(real.guest_capacity()==4,"Two operational starter rooms support four guests")
		var catalog = load("res://scripts/creative/creative_content.gd")
		var guest_beds: Array = []
		for object in real.hotel().objects:
			for room in real.hotel().rooms:
				if room.kind=="regular" and object.room==room.id and catalog.item(String(object.item)).get("role","")=="bed": guest_beds.append(object.id)
		for id in guest_beds:
			var emptied: Dictionary = real.commit("store_object",{"id":id})
			check(emptied.ok,"A starter guest room can be emptied: "+String(emptied.message))
		real.advance(0.25)
		var unready_guests: int = 0
		var guest_reservations: int = 0
		for actor in real.social.agents.values():
			if int(actor.cat)<1000: unready_guests += 1
		for owner in real.social.reservations.values():
			if int(owner)<1000: guest_reservations += 1
		check(real.guest_capacity()==0 and unready_guests==0 and guest_reservations==0,"Emptying both real guest rooms removes guest capacity and all guest reservations")
		real.new_game(1000)
		for cat in real.state.cats: cat.known=int(cat.id)==5
		var grass_bar: Dictionary = real.commit("place_object",{"item":"milkshake_counter","x":-11,"y":9.5,"rotation":0})
		var grass_seat: Dictionary = real.commit("place_object",{"item":"cafe_stool","x":-11,"y":11,"rotation":0})
		check(grass_bar.ok and grass_seat.ok,"A café counter and stool can be arranged on ordinary owned grass")
		var drank_on_grass: bool = false
		for _step in range(800):
			real.advance(0.25)
			for actor in real.social.agents.values():
				if int(actor.cat)>=1000: continue
				if actor.phase=="sit" and actor.drink:
					for object in real.hotel().objects:
						if object.id==actor.venue and object.item=="cafe_stool" and object.room=="": drank_on_grass=true
			if drank_on_grass: break
		check(drank_on_grass,"A guest checks in, crosses ordinary grass, orders and drinks at its outdoor stool")
	print("CREATIVE SOCIAL: %d failures" % failures)
	quit(1 if failures else 0)
