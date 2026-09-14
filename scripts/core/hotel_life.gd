extends RefCounted
const Content = preload("res://scripts/core/game_content.gd")
const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const Quality = preload("res://scripts/core/room_quality.gd")
var model_ref: WeakRef
var state: Dictionary = {}
var notices: Array = []

func _init() -> void:
	reset()

func bind(model) -> void:
	model_ref = weakref(model)
	_strip_legacy_state()

func _strip_legacy_state() -> void:
	state.erase("furniture")
	for hotel in state.hotels: hotel.erase("rooms")

func room_items(hotel: int, room: int) -> Array:
	var model = model_ref.get_ref() if model_ref != null else null
	if model != null: return model.furniture.room_items(hotel,room)
	return state.hotels[hotel].get("rooms",[])[room].map(func(id): return {"item":id})

func best_room(model, hotel: int, cat: int) -> int:
	var result := 0; var best := -1
	for room in range(model.room_count(hotel)):
		var fit := Quality.guest_fit(Quality.summarize(room_items(hotel,room)),room_tags(hotel,room),Content.PREFERENCES[cat])
		if fit > best: best=fit; result=room
	return result

func discover_combos(hotel: int, room: int) -> void:
	for combo in room_combos(hotel,room):
		if not state.combos.has(combo.id):
			state.combos.append(combo.id)
			memory("combo_"+combo.id,"Discovered: "+combo.name,"+%d coins/min in each room using this combination. %s cats feel at home." % [combo.bonus,combo.tag.capitalize()],state.favorite,hotel,"sniff")

func reset() -> void:
	state = {"seconds":0.0, "cats":[], "hotels":[], "furniture":["mat","box","plant"], "combos":[], "memories":[], "entitlements":[], "favorite":0, "pinned":"sunbeam", "revision":0}
	for i in range(Content.CAT_NAMES.size()):
		state.cats.append({"known":i < 3, "bond":0, "visits":0, "interactions":0, "last_touch":-100.0, "preference":false, "locations":[], "friend":-1})
	for i in range(4):
		var rooms: Array = []
		for j in range(8):
			rooms.append(["mat","box","plant"])
		state.hotels.append({"rooms":rooms, "specialty":"balanced", "visits":0, "happy":0, "stars":0, "visit_clock":0.0, "review":"Your first guests are settling in.", "staff":[0,0,0], "skills":[-1,-1,-1], "event":{}, "trophies":[], "last_event":-1000.0, "inspection":-1.0})
	notices.clear()
	if model_ref != null: _strip_legacy_state()

func touch() -> void:
	state.revision += 1

func owns(product_id: String) -> bool:
	return state.entitlements.has(product_id)

func has_cat(index: int) -> bool:
	return index >= 0 and index < state.cats.size() and (index < 12 or owns(Content.cat_pack(index)))

func known(index: int) -> bool:
	return has_cat(index) and state.cats[index].known

func discover(index: int, hotel: int = 0) -> void:
	if not has_cat(index) or state.cats[index].known:
		return
	state.cats[index].known = true
	memory("meet_%d" % index, "Meet " + Content.CAT_NAMES[index], Content.CAT_TRAITS[index] + ". A new regular with a story to tell.", index, hotel, "greet")
	touch()

func sync_discoveries(count: int) -> void:
	for index in range(mini(count, 12)):
		discover(index)

func memory(id: String, title: String, text: String, cat: int, hotel: int, pose: String = "rest", buddy: int = -1) -> void:
	for entry in state.memories:
		if entry.id == id:
			return
	state.memories.append({"id":id, "title":title, "text":text, "cat":cat, "hotel":hotel, "pose":pose, "buddy":buddy, "day":1 + int(state.seconds / 600.0)})
	# Content has a finite set of memory IDs. Notices are ephemeral and bounded.
	notices.append({"message":title, "cat":cat, "animation":pose, "buddy":buddy, "hotel":hotel})
	if notices.size() > 12:
		notices.pop_front()
	touch()

func bond(index: int, amount: int, hotel: int) -> void:
	var before: int = state.cats[index].bond
	state.cats[index].bond = mini(100, before + amount)
	for milestone in [20,50,100]:
		if before < milestone and state.cats[index].bond >= milestone:
			var titles = {20:"A familiar face", 50:"A little souvenir", 100:"A forever favorite"}
			memory("bond_%d_%d" % [index,milestone], Content.CAT_NAMES[index] + ": " + titles[milestone], ["A friendship blanket recipe, and a greeting just for you.", "A postcard from a favorite traveler.", "Your cat now welcomes you with a happy head bump."][[20,50,100].find(milestone)], index, hotel, "head_bump")
			if milestone == 20:
				var model = model_ref.get_ref() if model_ref != null else null
				if model != null and not model.furniture.state.legacy_reuse.has("blanket"):
					model.furniture.state.legacy_reuse.append("blanket")
					model.furniture.state.revision += 1
	touch()

func room_tags(hotel: int, room: int) -> Array:
	var tags: Array = []
	for instance in room_items(hotel,room):
		for tag in Catalog.item(instance.item).get("tags", []):
			if not tags.has(tag):
				tags.append(tag)
	return tags

func room_combos(hotel: int, room: int) -> Array:
	var result: Array = []
	var items: Array = room_items(hotel,room).map(func(instance): return instance.item)
	for combo in Content.COMBOS:
		if items.has(combo.items[0]) and items.has(combo.items[1]):
			result.append(combo)
	return result

func matching_rooms(model, hotel: int, tag: String) -> int:
	var total: int = 0
	for room in range(model.room_count(hotel)):
		if room_tags(hotel, room).has(tag):
			total += 1
	return total

func bonus_rate(model, hotel: int) -> int:
	var data: Dictionary = state.hotels[hotel]
	var total: int = 0
	for room in range(model.room_count(hotel)):
		for combo in room_combos(hotel, room):
			total += combo.bonus
		var tags: Array = room_tags(hotel, room)
		if data.specialty == "peaceful" and (tags.has("quiet") or tags.has("warm")):
			total += 4
		if data.specialty == "playful" and (tags.has("play") or tags.has("social")):
			total += 4
		var destination_tag: String = ["sunny","social","explore","warm"][hotel]
		if tags.has(destination_tag):
			total += 3
	if data.specialty == "gourmet":
		total += model.hotels[hotel].zones[1] * 3
	for level in data.staff:
		total += level * 2
	return total

func preference_score(model, hotel: int, cat: int) -> int:
	var tag: String = Content.PREFERENCES[cat]
	var data: Dictionary = state.hotels[hotel]
	var zones: Array = model.hotels[hotel].zones
	var score: int = 35 + mini(25, zones[0] * 3) + mini(20, matching_rooms(model, hotel, tag) * 12)
	var preferred_combo: bool = false
	for room in range(model.room_count(hotel)):
		for combo in room_combos(hotel,room):
			if combo.tag == tag:
				preferred_combo = true
	if preferred_combo:
		score += 15
	if tag == "food":
		score += mini(30, zones[1] * 7)
	elif tag in ["play","social"]:
		score += mini(20, zones[2] * 5)
	for specialization in Content.SPECIALTIES:
		if specialization.id == data.specialty and specialization.tag == tag:
			score += 12
	var skill_tags = [["quiet","social"],["quiet","food"],["warm","play"]]
	for s in range(3):
		score += data.staff[s] * 2
		if data.skills[s] >= 0 and skill_tags[s][data.skills[s]] == tag:
			score += 8
	var best := best_room(model,hotel,cat)
	var fit := Quality.guest_fit(Quality.summarize(room_items(hotel,best)),room_tags(hotel,best),tag)
	return mini(100, score + mini(10,int(fit / 10)))

func visit_interval(model, hotel: int) -> float:
	return maxf(18.0, 50.0 - model.hotels[hotel].zones[3] * 2.0 - state.hotels[hotel].staff[0] * 2.0)

func visit(model, hotel: int, cat: int) -> void:
	if not known(cat):
		return
	var data: Dictionary = state.hotels[hotel]
	var visitor: Dictionary = state.cats[cat]
	data.visits += 1
	visitor.visits += 1
	if not visitor.locations.has(hotel):
		visitor.locations.append(hotel)
	var score: int = preference_score(model, hotel, cat)
	if score >= 65:
		data.happy += 1
		bond(cat, 3, hotel)
		visitor.preference = true
		data.review = "%s: %d/100 — I loved %s!" % [Content.CAT_NAMES[cat], score, Content.PREFERENCE_COPY[Content.PREFERENCES[cat]]]
		memory("happy_%d_%d" % [hotel,cat], Content.CAT_NAMES[cat] + " recommends your hotel", data.review, cat, hotel, "greet")
		# Shared interests introduce one dependable new base guest.
		for next in range(12):
			if not known(next) and Content.PREFERENCES[next] == Content.PREFERENCES[cat]:
				discover(next, hotel)
				break
	else:
		data.review = "%s: %d/100 — I'd love %s." % [Content.CAT_NAMES[cat], score, Content.PREFERENCE_COPY[Content.PREFERENCES[cat]]]
	if visitor.visits >= 2:
		var poses = ["box", "blanket", "zoomies", "missed_jump", "groom", "yawn"]
		var pose: String = poses[cat % poses.size()]
		memory("habit_%d" % cat, Content.CAT_NAMES[cat] + "'s little habit", ["The delivery box is apparently the best room in the house.", "A blanket has acquired a suspiciously cat-shaped lump.", "A sudden burst of speed, followed by a very long nap.", "That cushion was slightly farther away than expected.", "Every whisker must be in precisely the right place.", "Supervising this hotel is exhausting work."][cat % 6], cat, hotel, pose)
	if notices.size()<12:
		notices.append({"message":Content.CAT_NAMES[cat]+" is checking in.","cat":cat,"animation":"visit","hotel":hotel})
	touch()

func advance(seconds: float, model) -> void:
	if seconds <= 0:
		return
	state.seconds += seconds
	for hotel in range(model.hotels.size()):
		if not model.hotels[hotel].owned:
			continue
		var data: Dictionary = state.hotels[hotel]
		data.visit_clock += seconds
		var interval: float = visit_interval(model, hotel)
		# At most a few summaries for large offline intervals; no simulated need penalties.
		var visits: int = mini(8, int(data.visit_clock / interval))
		if visits > 0:
			data.visit_clock = fmod(data.visit_clock, interval)
			var guests: Array = []
			for cat in range(state.cats.size()):
				if known(cat):
					guests.append(cat)
			for n in range(visits):
				if not guests.is_empty():
					visit(model, hotel, guests[data.visits % guests.size()])
		if data.inspection >= 0 and state.seconds >= data.inspection:
			data.inspection = -1.0
			finish_inspection(model, hotel)
		if not data.event.is_empty() and state.seconds >= data.event.ends:
			finish_event(model, hotel)

func star_checks(model, hotel: int) -> Array:
	var data: Dictionary = state.hotels[hotel]
	var combinations: int = 0
	for room in range(model.room_count(hotel)):
		combinations += room_combos(hotel, room).size()
	var staff_total: int = 0
	for level in data.staff:
		staff_total += level
	return [
		{"name":"Welcome 3 happy visits", "ready":data.happy >= 3},
		{"name":"Create a room combination and welcome 6 happy visits", "ready":combinations >= 1 and data.happy >= 6},
		{"name":"Choose a specialty and earn an event trophy", "ready":data.specialty != "balanced" and data.trophies.size() > 0},
		{"name":"Open 4 rooms and train staff 3 times", "ready":model.room_count(hotel) >= 4 and staff_total >= 3},
		{"name":"Create 3 room combinations and welcome 20 happy visits", "ready":combinations >= 3 and data.happy >= 20}
	]

func finish_inspection(model, hotel: int) -> void:
	var checks: Array = star_checks(model, hotel)
	var stars: int = 0
	for item in checks:
		if not item.ready:
			break
		stars += 1
	state.hotels[hotel].stars = maxi(state.hotels[hotel].stars, stars)
	state.hotels[hotel].review = "Inspector Whiskers: %d stars. %s" % [stars, "An extraordinary home for cats!" if stars == 5 else "Next: " + checks[stars].name + "."]
	memory("stars_%d_%d" % [hotel,stars], "%s: %d-star review" % [model.HOTEL_NAMES[hotel], stars], state.hotels[hotel].review, 0, hotel, "inspect")
	touch()

func event_score(model, hotel: int, id: String) -> int:
	var event: Dictionary = Content.find_event(id)
	var staff: Array = state.hotels[hotel].staff
	return mini(100, 30 + matching_rooms(model,hotel,event.tag) * 18 + (staff[0]+staff[1]+staff[2]) * 4 + state.hotels[hotel].happy)

func finish_event(model, hotel: int) -> void:
	var data: Dictionary = state.hotels[hotel]
	var event: Dictionary = Content.find_event(data.event.id)
	var score: int = data.event.score
	var medal: String = "Gold" if score >= 80 else ("Silver" if score >= 55 else "Bronze")
	var first: bool = not data.trophies.has(event.id)
	if first:
		data.trophies.append(event.id)
		model.coins_units += 250 * model.UNIT
	memory("event_%d_%s_%s" % [hotel,event.id,medal], medal + ": " + event.name, "%d/100. %s" % [score, "Your first trophy brought a 250-coin prize." if first else "Another happy gathering for your regulars."], 0, hotel, "celebrate")
	data.event = {}
	data.last_event = state.seconds
	touch()

func perform(model, action: String, payload: Dictionary) -> Dictionary:
	var hotel: int = model.current_hotel
	var data: Dictionary = state.hotels[hotel]
	match action:
		"furnish":
			return failure("Open Build mode to arrange and apply furniture.")
		"specialty":
			var id: String = str(payload.get("id", ""))
			if model.hotel_level(hotel) < 3:
				return failure("Reach hotel level 3 to choose a specialty.")
			for option in Content.SPECIALTIES:
				if option.id == id:
					data.specialty = id
					touch()
					return success("Your hotel is now " + option.name.to_lower() + ".")
		"interact":
			var cat: int = int(payload.get("cat", -1))
			var kind: String = str(payload.get("kind", "pet"))
			if not known(cat) or not ["pet","brush","wand","yarn","cushion","box","bell"].has(kind):
				return failure("Meet this guest before inviting them to play.")
			var visitor: Dictionary = state.cats[cat]
			var message: String = Content.CAT_NAMES[cat] + " enjoys your company."
			if state.seconds - visitor.last_touch >= 12.0:
				visitor.last_touch = state.seconds
				visitor.interactions += 1
				bond(cat, 6 if Content.FAVORITE_ACTIONS[cat] == kind else 3, hotel)
				if visitor.interactions >= 2 or Content.FAVORITE_ACTIONS[cat] == kind:
					visitor.preference = true
					message = Content.CAT_NAMES[cat] + " loves " + Content.PREFERENCE_COPY[Content.PREFERENCES[cat]] + "."
				memory("play_%d_%s" % [cat,kind], Content.CAT_NAMES[cat] + " · " + kind.capitalize() + " time", message, cat, hotel, {"pet":"purr", "wand":"pounce", "yarn":"chase", "cushion":"settle", "bell":"greet"}.get(kind,kind))
			touch()
			return {"ok":true, "message":message, "animation":{"pet":"purr", "wand":"pounce", "yarn":"chase", "cushion":"settle", "bell":"greet"}.get(kind,kind), "cat":cat}
		"favorite":
			var cat: int = int(payload.get("cat", -1))
			if known(cat):
				state.favorite = cat
				touch()
				return success(Content.CAT_NAMES[cat] + " is your favorite.")
		"invite":
			var cat: int = int(payload.get("cat", -1))
			if not has_cat(cat):
				return failure("This traveler belongs to an expansion pack.")
			if not known(cat) and matching_rooms(model,hotel,Content.PREFERENCES[cat]) == 0:
				return failure("Prepare " + Content.PREFERENCE_COPY[Content.PREFERENCES[cat]] + " first.")
			discover(cat,hotel)
			# Inviting is not a repeatable way to farm visits or rewards.
			memory("invite_%d_%d" % [hotel,cat], "A room for " + Content.CAT_NAMES[cat], "Your invitation has arrived. A familiar face is on the way.", cat, hotel, "arrival")
			return {"ok":true,"message":Content.CAT_NAMES[cat] + " is visiting!", "animation":"arrival", "cat":cat, "rebuild":true}
		"playdate":
			var cat: int = int(payload.get("cat", -1))
			var other: int = int(payload.get("other", -1))
			if not known(cat) or not known(other) or cat == other:
				return failure("Choose two different regulars.")
			if state.cats[cat].bond < 10 or state.cats[other].bond < 10:
				return failure("Get to know both cats a little first (10 friendship each).")
			if not model.hotels[hotel].zones[2] > 0:
				return failure("Open the lounge to host a playdate.")
			state.cats[cat].friend = other
			state.cats[other].friend = cat
			memory("friends_%d_%d" % [mini(cat,other),maxi(cat,other)], Content.CAT_NAMES[cat] + " & " + Content.CAT_NAMES[other], "A nose greeting, a shared game, and two very sleepy friends.", cat, hotel, "friendship", other)
			touch()
			return {"ok":true,"message":"A new friendship!", "animation":"friendship", "cat":cat, "buddy":other}
		"train":
			var staff: int = int(payload.get("staff", -1))
			if staff < 0 or staff >= 3 or data.staff[staff] >= 3:
				return failure("This staff member has completed their training.")
			if model.hotels[hotel].zones[Content.STAFF[staff].zone] == 0:
				return failure("Open this staff member's service first.")
			var cost: int = 250 * (data.staff[staff] + 1)
			if model.coins < cost:
				return failure("Training costs %d Cat Coins." % cost)
			model.coins_units -= cost * model.UNIT
			data.staff[staff] += 1
			memory("staff_%d_%d_%d" % [hotel,staff,data.staff[staff]], Content.STAFF[staff].name + " learned something new", Content.STAFF[staff].copy, 0, hotel, "work")
			touch()
			return success("Training complete. Choose a staff specialty.", "celebrate")
		"skill":
			var staff: int = int(payload.get("staff", -1))
			var skill: int = int(payload.get("skill", -1))
			if staff >= 0 and staff < 3 and skill >= 0 and skill < 2 and data.staff[staff] > 0:
				data.skills[staff] = skill
				touch()
				return success(Content.STAFF[staff].skills[skill] + " selected.")
		"event":
			var event: Dictionary = Content.find_event(str(payload.get("id", "")))
			if event.is_empty() or (event.hotel >= 0 and event.hotel != hotel):
				return failure("That event belongs to another destination.")
			if not data.event.is_empty() or state.seconds - data.last_event < 60:
				return failure("Your guests are enjoying their last gathering. Try again soon.")
			data.event = {"id":event.id, "ends":state.seconds + event.seconds, "score":event_score(model,hotel,event.id)}
			touch()
			return success(event.name + " has begun!", "celebrate", true)
		"inspect":
			if data.inspection >= 0:
				return failure("Inspector Whiskers is already visiting.")
			data.inspection = state.seconds + 12.0
			touch()
			return success("Inspector Whiskers is touring your hotel.", "inspect")
		"pin":
			for combo in Content.COMBOS:
				if combo.id == str(payload.get("id", "")):
					state.pinned = combo.id
					touch()
					return success("Pinned: " + combo.name)
	return failure("That action is not available yet.")

func grant_product(model, product_id: String) -> bool:
	var item: Dictionary = Content.product(product_id)
	if item.is_empty():
		return false
	if not owns(product_id):
		state.entitlements.append(product_id)
	for hotel in item.hotels:
		model.hotels[hotel].owned = true
		model.furniture.ensure_rooms(model,hotel)
	for cat in item.cats:
		discover(cat, model.current_hotel)
	touch()
	return true

func success(message: String, animation: String = "", rebuild: bool = false) -> Dictionary:
	return {"ok":true,"message":message,"animation":animation,"rebuild":rebuild}

func failure(message: String) -> Dictionary:
	return {"ok":false,"message":message}

func serialize() -> Dictionary:
	var result := state.duplicate(true)
	result.erase("furniture")
	for hotel in result.hotels: hotel.erase("rooms")
	return result

func restore(raw: Variant, furniture_version: bool = false) -> bool:
	# Validate into a candidate before replacing state. A bad newest save can fall back.
	if not raw is Dictionary:
		return false
	var candidate: Dictionary = raw.duplicate(true)
	if furniture_version:
		if candidate.has("furniture") or not candidate.get("hotels") is Array: return false
		candidate.furniture = ["mat","box","plant"]
		for hotel in candidate.hotels:
			if not hotel is Dictionary or hotel.has("rooms"): return false
			hotel.rooms = []
			for room in range(8): hotel.rooms.append(["mat","box","plant"])
	for key in ["seconds","revision","favorite"]:
		if not numeric(candidate.get(key)) or candidate[key] < 0:
			return false
	if candidate.seconds > 9000000000 or not whole(candidate.favorite) or candidate.favorite >= Content.CAT_NAMES.size():
		return false
	if not candidate.get("cats") is Array or candidate.cats.size() != Content.CAT_NAMES.size() or not candidate.get("hotels") is Array or candidate.hotels.size() != 4:
		return false
	for key in ["furniture","combos","memories","entitlements"]:
		if not candidate.get(key) is Array:
			return false
	if candidate.memories.size() > 2000 or not candidate.get("pinned") is String:
		return false
	for id in candidate.entitlements:
		if not id is String or Content.product(id).is_empty():
			return false
	for id in candidate.furniture:
		if not id is String or Content.find_item(id).is_empty():
			return false
	for cat in candidate.cats:
		if not cat is Dictionary or not cat.get("known") is bool or not cat.get("preference") is bool or not cat.get("locations") is Array:
			return false
		for key in ["bond","visits","interactions","friend"]:
			if not whole(cat.get(key)):
				return false
		if cat.bond < 0 or cat.bond > 100 or cat.visits < 0 or cat.interactions < 0 or cat.friend < -1 or cat.friend >= Content.CAT_NAMES.size() or not numeric(cat.get("last_touch")):
			return false
		for place in cat.locations:
			if not whole(place) or place < 0 or place > 3:
				return false
	for hotel in candidate.hotels:
		if not hotel is Dictionary or not hotel.get("rooms") is Array or hotel.rooms.size() != 8 or not hotel.get("event") is Dictionary or not hotel.get("trophies") is Array or not hotel.get("review") is String:
			return false
		if not ["balanced","peaceful","playful","gourmet"].has(hotel.get("specialty")):
			return false
		for key in ["visits","happy","stars"]:
			if not whole(hotel.get(key)) or hotel[key] < 0:
				return false
		if hotel.stars > 5:
			return false
		for key in ["visit_clock","last_event","inspection"]:
			if not numeric(hotel.get(key)):
				return false
		for key in ["staff","skills"]:
			if not hotel.get(key) is Array or hotel[key].size() != 3:
				return false
		for level in hotel.staff:
			if not whole(level) or level < 0 or level > 3:
				return false
		for skill in hotel.skills:
			if not whole(skill) or skill < -1 or skill > 1:
				return false
		for room in hotel.rooms:
			if not room is Array or room.size() != 3:
				return false
			for slot in range(3):
				if not room[slot] is String or not candidate.furniture.has(room[slot]) or Content.find_item(room[slot]).get("slot",-1) != slot:
					return false
		if not hotel.event.is_empty():
			if not hotel.event.get("id") is String or Content.find_event(hotel.event.id).is_empty() or not numeric(hotel.event.get("ends")) or not whole(hotel.event.get("score")) or hotel.event.score < 0 or hotel.event.score > 100:
				return false
	for entry in candidate.memories:
		if not entry is Dictionary:
			return false
		for key in ["id","title","text","pose"]:
			if not entry.get(key) is String:
				return false
		for key in ["cat","hotel","day","buddy"]:
			if not whole(entry.get(key)):
				return false
		if entry.cat < 0 or entry.cat >= Content.CAT_NAMES.size() or entry.hotel < 0 or entry.hotel > 3:
			return false
		if entry.has("photo") and (not entry.photo is String or not entry.photo.begins_with("user://photos/") or entry.photo.contains("..")):
			return false
	candidate.favorite = int(candidate.favorite)
	candidate.revision = int(candidate.revision)
	for cat in candidate.cats:
		for key in ["bond","visits","interactions","friend"]:
			cat[key] = int(cat[key])
		cat.locations = cat.locations.map(func(value): return int(value))
	for hotel in candidate.hotels:
		for key in ["visits","happy","stars"]:
			hotel[key] = int(hotel[key])
		hotel.staff = hotel.staff.map(func(value): return int(value))
		hotel.skills = hotel.skills.map(func(value): return int(value))
		if not hotel.event.is_empty():
			hotel.event.score = int(hotel.event.score)
	for entry in candidate.memories:
		for key in ["cat","hotel","day","buddy"]:
			entry[key] = int(entry[key])
	state = candidate
	notices.clear()
	return true

func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func whole(value: Variant) -> bool:
	return numeric(value) and value == floor(value)
