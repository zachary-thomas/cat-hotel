extends RefCounted
## Pure economy model. Rendering and wall-clock reads belong to the controller.
const Content = preload("res://scripts/core/game_content.gd")
const RoomLayout = preload("res://scripts/core/room_layout.gd")
const Life = preload("res://scripts/core/hotel_life.gd")
var life = Life.new()
const Inventory = preload("res://scripts/core/furniture_inventory.gd")
const Quality = preload("res://scripts/core/room_quality.gd")
var furniture = Inventory.new()
const Grounds = preload("res://scripts/core/grounds_model.gd")
var grounds = Grounds.new()

const UNIT: int = 1000000
const OFFLINE_CAP: int = 28800
const HOTEL_NAMES = ["Meadow House", "Seaside Suites", "Forest Lodge", "Snowcap Spa"]
const HOTEL_SUBTITLES = ["A little home for happy cats", "Sunshine, sea air & soft paws", "A hideaway among the trees", "Warm hearts. Snowy rooftops."]
const ZONE_NAMES = ["Cozy suites", "Cat kitchen", "Play lounge", "Reception"]
const ZONE_DETAILS = ["A softer place to curl up.", "Good food. Very happy guests.", "More room for little adventures.", "Every stay starts with a warm welcome."]
const WING_NAMES = ["Garden rooms", "Courtyard rooms", "Skyview rooms"]
const WING_COSTS = [1200, 3500, 8000]
const WING_LEVELS = [2, 4, 6]
const WING_RATES = [30, 50, 80]
const REPAIR_SECONDS = [30.0, 60.0, 90.0]
const CAT_NAMES = Content.CAT_NAMES
const CAT_TRAITS = Content.CAT_TRAITS

var coins_units: int = 0
var fraction: float = 0.0
var coins: float:
	get: return float(coins_units) / UNIT
	set(value): coins_units = int(round(value * UNIT))
var hotels: Array = []
var current_hotel: int = 0
var pending_units: int = 0
var pending_coins: float:
	get: return float(pending_units) / UNIT
var pending_seconds: int = 0
var away_seconds: int = 0
var last_seen: int = 0
var started: bool = false
var settings: Dictionary = {"motion": true, "sound": true, "music": true, "evening": false, "haptics": true, "weather": true, "watch": false, "exterior": false, "build_text_scale":1.0, "ui_text_scale":1.0}

func _init() -> void:
	life.bind(self)

func new_game(now: int) -> void:
	coins_units = 1000 * UNIT
	fraction = 0.0
	hotels = []
	for index in range(4):
		hotels.append({"owned":index == 0,"zones":[1,0,0,0],"purchases":0,"wings":0})
		RoomLayout.migrate(hotels[index])
	life.reset()
	furniture.reset()
	furniture.ensure_rooms(self,0)
	grounds.reset()
	current_hotel = 0
	pending_units = 0
	pending_seconds = 0
	away_seconds = 0
	last_seen = now
	started = true

func rate() -> int:
	var total: int = 0
	for i in range(hotels.size()):
		total += hotel_rate(i)
	return total

func hotel_rate(index: int) -> int:
	if index < 0 or index >= hotels.size() or not hotels[index].owned:
		return 0
	var total: int = 0
	for level in hotels[index].zones:
		total += int(level) * 10
	for wing in range(wing_count(index)):
		total += WING_RATES[wing]
	var rooms: Array = RoomLayout.entries(self, index)
	for room in range(2, rooms.size()):
		total += RoomLayout.income(rooms[room].kind)
	for room in range(rooms.size()):
		total += int(Quality.summarize(furniture.room_items(index,room)).income)
	total += int(Quality.summarize(furniture.room_items(index,-2)).income)
	total += life.bonus_rate(self,index)
	total += grounds.bonus_rate(index)
	return total

func wing_count(index: int) -> int:
	return int(hotels[index].get("wings", 0)) if index >= 0 and index < hotels.size() else 0

func room_count(index: int) -> int:
	return RoomLayout.entries(self, index).size() if index >= 0 and index < hotels.size() and hotels[index].owned else 0

func expansion_cost(index: int) -> int:
	if index < 0 or index >= hotels.size() or not hotels[index].owned or wing_count(index) >= WING_COSTS.size():
		return 0
	return WING_COSTS[wing_count(index)]

func can_expand(index: int) -> bool:
	var cost: int = expansion_cost(index)
	return cost > 0 and repair_remaining(index) <= 0 and coins_units >= cost * UNIT and hotel_level(index) >= WING_LEVELS[wing_count(index)]

func repair_remaining(index: int) -> float:
	return float(hotels[index].get("repair_remaining", 0.0)) if index >= 0 and index < hotels.size() else 0.0

func start_repair(index: int) -> bool:
	if not can_expand(index):
		return false
	coins_units -= expansion_cost(index) * UNIT
	hotels[index].repair_remaining = REPAIR_SECONDS[wing_count(index)]
	return true

func _advance_repairs(seconds: float) -> void:
	for index in range(hotels.size()):
		var remaining: float = repair_remaining(index)
		if remaining <= 0:
			continue
		hotels[index].repair_remaining = maxf(0, remaining - seconds)
		if hotels[index].repair_remaining == 0:
			RoomLayout.entries(self, index)
			hotels[index].wings = wing_count(index) + 1
			life.sync_discoveries(discovered_cats())

func expand(index: int) -> bool:
	if not can_expand(index):
		return false
	coins_units -= expansion_cost(index) * UNIT
	RoomLayout.entries(self, index)
	hotels[index].wings = wing_count(index) + 1
	life.sync_discoveries(discovered_cats())
	return true

func hotel_level(index: int) -> int:
	if index < 0 or index >= hotels.size():
		return 0
	return mini(10, 1 + int(hotels[index].purchases / 2))

func upgrade_cost(hotel: int, zone: int) -> int:
	if not _valid_zone(hotel, zone) or int(hotels[hotel].zones[zone]) >= 10:
		return 0
	return int(round(240.0 * pow(2.0, float(hotels[hotel].zones[zone]) / 3.0)))

func _valid_zone(hotel: int, zone: int) -> bool:
	return hotel >= 0 and hotel < hotels.size() and hotels[hotel].owned and zone >= 0 and zone < 4

func advance(seconds: float) -> void:
	if not started or seconds <= 0 or not is_finite(seconds):
		return
	# Split at completion so a wing earns only after the builders finish.
	var step: float = seconds
	for index in range(hotels.size()):
		if repair_remaining(index) > 0:
			step = minf(step, repair_remaining(index))
	var units: float = float(rate() * UNIT) * step / 60.0 + fraction
	var whole: int = int(floor(units))
	coins_units += whole
	fraction = units - whole
	life.advance(step, self)
	grounds.advance(step, self)
	_advance_repairs(step)
	if seconds > step:
		advance(seconds - step)

func upgrade(hotel: int, zone: int) -> bool:
	var cost: int = upgrade_cost(hotel, zone)
	if cost <= 0 or coins_units < cost * UNIT:
		return false
	coins_units -= cost * UNIT
	hotels[hotel].zones[zone] = int(hotels[hotel].zones[zone]) + 1
	hotels[hotel].purchases = int(hotels[hotel].purchases) + 1
	life.sync_discoveries(discovered_cats())
	return true

func unlock_hotel(index: int) -> bool:
	if index != 1 or hotels.size() < 2 or hotels[1].owned or hotel_level(0) < 10 or coins_units < 10000 * UNIT:
		return false
	coins_units -= 10000 * UNIT
	hotels[1].owned = true
	furniture.ensure_rooms(self,1)
	current_hotel = 1
	return true

func reconcile(now: int) -> void:
	if not started or now <= last_seen:
		return
	var elapsed: int = now - last_seen
	last_seen = now
	if elapsed < 60 and pending_units == 0:
		advance(float(elapsed))
		return
	away_seconds += elapsed
	var credited: int = mini(elapsed, maxi(0, OFFLINE_CAP - pending_seconds))
	# Reuse the same completion boundaries without claiming offline earnings.
	var wallet: int = coins_units
	var residue: float = fraction
	advance(float(credited))
	pending_units += coins_units - wallet
	coins_units = wallet
	fraction = residue
	pending_seconds += credited
	# Building continues during longer absences even beyond the income cap.
	_advance_repairs(float(elapsed - credited))
	# Assigned chores still finish after the passive-income cap. Their one-time
	# rewards wait in the collection envelope, without adding more passive income.
	var before_jobs: int = coins_units
	grounds.advance(float(elapsed - credited),self)
	pending_units += coins_units - before_jobs
	coins_units = before_jobs

func claim() -> int:
	var result: int = int(pending_units / UNIT)
	coins_units += pending_units
	pending_units = 0
	pending_seconds = 0
	away_seconds = 0
	return result

func discovered_cats() -> int:
	var purchases: int = 0
	for hotel in hotels:
		if hotel.owned:
			purchases += int(hotel.purchases) + int(hotel.get("wings", 0)) * 4
	return mini(12, 3 + int(purchases / 2))

func serialize() -> Dictionary:
	return {"version": 3, "started": started, "coins_units": coins_units, "fraction": fraction, "hotels": hotels.duplicate(true), "current_hotel": current_hotel, "pending_units": pending_units, "pending_seconds": pending_seconds, "away_seconds": away_seconds, "last_seen": last_seen, "settings": settings.duplicate(), "life":life.serialize(), "grounds":grounds.serialize(), "furniture":furniture.serialize()}

func restore(data: Dictionary) -> bool:
	# The candidate owns validation and migration; live state never changes on failure.
	var candidate = get_script().new()
	if not candidate._restore_candidate(data): return false
	for key in ["coins_units","fraction","hotels","current_hotel","pending_units","pending_seconds","away_seconds","last_seen","started","settings","life","grounds","furniture"]:
		set(key,candidate.get(key))
	life.bind(self)
	return true

func _restore_candidate(data: Dictionary) -> bool:
	if not _whole(data.get("version")) or int(data.version) not in [1,2,3] or data.get("started") != true:
		return false
	for key in ["coins_units", "pending_units", "pending_seconds", "away_seconds", "last_seen", "current_hotel"]:
		if not _whole(data.get(key)) or float(data[key]) < 0 or float(data[key]) > 9000000000000000:
			return false
	if int(data.pending_seconds) > OFFLINE_CAP or int(data.away_seconds) < int(data.pending_seconds):
		return false
	var residue = data.get("fraction", 0.0)
	if not (residue is float or residue is int) or not is_finite(float(residue)) or float(residue) < 0.0 or float(residue) >= 1.0:
		return false
	var entries = data.get("hotels")
	if not entries is Array or entries.size() != (2 if data.version == 1 else 4):
		return false
	for entry in entries:
		if not entry is Dictionary or not entry.get("owned") is bool or not entry.get("zones") is Array or entry.zones.size() != 4 or not _whole(entry.get("purchases")) or int(entry.purchases) < 0 or int(entry.purchases) > 45:
			return false
		for level in entry.zones:
			if not _whole(level) or int(level) < 0 or int(level) > 10:
				return false
		var wings = entry.get("wings", 0)
		if not _whole(wings) or int(wings) < 0 or int(wings) > WING_COSTS.size():
			return false
		if entry.has("layout") and not RoomLayout.valid_saved(entry.layout, int(wings)):
			return false
		var remaining = entry.get("repair_remaining", 0.0)
		if not (remaining is float or remaining is int) or not is_finite(float(remaining)) or float(remaining) < 0:
			return false
		if float(remaining) > 0 and (not entry.owned or int(wings) >= 3 or float(remaining) > REPAIR_SECONDS[int(wings)]):
			return false
	var selected: int = int(data.current_hotel)
	if not entries[0].owned or selected >= entries.size() or not entries[selected].owned:
		return false
	var restored_life = Life.new()
	if data.version >= 2 and not restored_life.restore(data.get("life"),data.version == 3):
		return false
	var restored_grounds = Grounds.new()
	if not restored_grounds.restore(data.get("grounds")):
		return false
	for index in range(entries.size()):
		var garden: Dictionary=restored_grounds.hotels[index]
		for id in garden.amenity_layout:
			var place: Dictionary=garden.amenity_layout[id]
			if not Grounds.Garden.validate(garden,Grounds.AMENITIES,id,Vector2(place.x,place.z),int(place.rotation),int(entries[index].get("wings",0))).ok: return false
	var migrated_hotels: Array[int] = []
	for index in range(entries.size()):
		if entries[index].owned and not entries[index].has("layout"):
			migrated_hotels.append(index)
	grounds = restored_grounds
	coins_units = int(data.coins_units)
	fraction = float(residue)
	hotels = entries.duplicate(true)
	while hotels.size() < 4:
		hotels.append({"owned":false,"zones":[1,0,0,0],"purchases":0,"wings":0})
	life = restored_life
	for entry in hotels:
		entry["wings"] = int(entry.get("wings", 0))
		RoomLayout.migrate(entry)
	if data.version == 3:
		if not furniture.restore(data.get("furniture"),hotels): return false
	else:
		var source := data.duplicate(true)
		source.hotels = hotels.duplicate(true)
		var migration: Dictionary = furniture.migrate(source)
		if not migration.ok or not furniture.restore(migration.state,hotels): return false
	life.bind(self)
	current_hotel = selected
	pending_units = int(data.pending_units)
	pending_seconds = int(data.pending_seconds)
	away_seconds = int(data.away_seconds)
	last_seen = int(data.last_seen)
	started = true
	var saved_settings = data.get("settings", {})
	if saved_settings is Dictionary:
		if saved_settings.has("build_text_scale"):
			if saved_settings.build_text_scale not in [1.0,1.25,1.5]: return false
			settings.build_text_scale = float(saved_settings.build_text_scale)
		var scale_value = saved_settings.get("ui_text_scale", settings.build_text_scale)
		if not (scale_value is float or scale_value is int) or scale_value not in [1.0,1.25,1.5]:
			return false
		settings.ui_text_scale = float(scale_value)
		# Respect a player's existing mute preference when loading an older save.
		settings.music = saved_settings.get("music", saved_settings.get("sound", true)) == true
		for key in settings.keys():
			if saved_settings.get(key) is bool:
				settings[key] = saved_settings[key]
	life.sync_discoveries(discovered_cats())
	for index in migrated_hotels:
		grounds.layout_changed(self, index)
	return true

func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))
