extends RefCounted
## Shared, stable content IDs are also save-file IDs. Never reuse an ID for another item.

const COATS = ["d99c51", "999e93", "343e35", "e3d5b9", "829d91", "cda46f", "68757b", "c48354", "393e50", "c8ad92", "896755", "f0e3cc", "bd9dac", "cb743b", "6c8196", "eee5d3", "806452", "a7c2c0"]
const CAT_NAMES = ["Miso", "Clover", "Bean", "Mochi", "Olive", "Biscuit", "Pebble", "Maple", "Nori", "Pip", "Coco", "Tofu", "Truffle", "Ember", "Captain", "Flurry", "Juniper", "Pearl"]
const CAT_TRAITS = ["Sun seeker", "Curious explorer", "Playful soul", "Professional napper", "Quiet observer", "Snack enthusiast", "Window watcher", "Friendly traveler", "Night owl", "Little adventurer", "Lounge lover", "Gentle dreamer", "Velvet storyteller", "Autumn acrobat", "Seafaring napper", "Snowflake collector", "Woodland wanderer", "Spa connoisseur"]
const PREFERENCES = ["sunny", "explore", "play", "quiet", "quiet", "food", "sunny", "social", "warm", "explore", "social", "warm", "quiet", "explore", "social", "warm", "explore", "warm"]
const FAVORITE_ACTIONS = ["pet", "box", "wand", "cushion", "brush", "bell", "pet", "yarn", "brush", "wand", "yarn", "cushion", "brush", "wand", "box", "cushion", "box", "pet"]
const PREFERENCE_COPY = {"sunny": "a perch beside a warm window", "explore": "climbing towers and places to explore", "play": "tunnels, toys and a lively lounge", "quiet": "a sheltered bed and a peaceful corner", "food": "a good kitchen and a welcoming table", "social": "shared activities and friendly company", "warm": "heated cushions and soft evening lamps"}
const FURNITURE = [
	{"id":"mat", "name":"Linen mat", "slot":0, "cost":0, "tags":[], "level":1},
	{"id":"sun_cushion", "name":"Sunshine cushion", "slot":0, "cost":120, "tags":["sunny"], "level":1},
	{"id":"cave", "name":"Sheltered cat bed", "slot":0, "cost":180, "tags":["quiet"], "level":1},
	{"id":"heated", "name":"Heated cloud bed", "slot":0, "cost":320, "tags":["warm"], "level":2},
	{"id":"box", "name":"Delivery box", "slot":1, "cost":0, "tags":["explore"], "level":1},
	{"id":"perch", "name":"Window perch", "slot":1, "cost":150, "tags":["sunny"], "level":1},
	{"id":"tunnel", "name":"Play tunnel", "slot":1, "cost":190, "tags":["play"], "level":1},
	{"id":"tower", "name":"Climbing tower", "slot":1, "cost":260, "tags":["explore","play"], "level":2},
	{"id":"table", "name":"Picnic table", "slot":1, "cost":250, "tags":["food","social"], "level":2},
	{"id":"plant", "name":"Leafy planter", "slot":2, "cost":0, "tags":[], "level":1},
	{"id":"rug", "name":"Whisper-soft rug", "slot":2, "cost":110, "tags":["quiet"], "level":1},
	{"id":"scratch", "name":"Rope scratcher", "slot":2, "cost":140, "tags":["play"], "level":1},
	{"id":"lamp", "name":"Amber lantern", "slot":2, "cost":230, "tags":["warm"], "level":2},
	{"id":"flowers", "name":"Welcome flowers", "slot":2, "cost":160, "tags":["social"], "level":1},
	{"id":"blanket", "name":"Friendship blanket", "slot":0, "cost":0, "tags":["quiet","warm"], "level":1, "bond":20}
	,{"id":"cloud_sofa", "name":"Cloud sofa", "slot":1, "cost":420, "tags":["social","warm"], "level":3}
	,{"id":"adventure_tree", "name":"Adventure tree", "slot":1, "cost":650, "tags":["explore","play"], "level":4}
	,{"id":"canopy_bed", "name":"Canopy bed", "slot":0, "cost":900, "tags":["quiet"], "level":5}
]
const COMBOS = [
	{"id":"sunbeam", "name":"Sunbeam Suite", "items":["sun_cushion","perch"], "tag":"sunny", "bonus":8, "clue":"A sunny seat deserves a sunny cushion."},
	{"id":"adventure", "name":"Tiny Adventure Club", "items":["tunnel","scratch"], "tag":"play", "bonus":8, "clue":"Something to crawl through, something to scratch."},
	{"id":"retreat", "name":"Quiet Retreat", "items":["cave","rug"], "tag":"quiet", "bonus":8, "clue":"A sheltered bed needs the softest floor."},
	{"id":"treetops", "name":"Treetop Hideaway", "items":["tower","plant"], "tag":"explore", "bonus":8, "clue":"A little tree belongs among leaves."},
	{"id":"picnic", "name":"Friendly Picnic", "items":["table","flowers"], "tag":"social", "bonus":8, "clue":"Welcome friends to a table in bloom."},
	{"id":"cloud", "name":"Cloud Nine", "items":["heated","lamp"], "tag":"warm", "bonus":8, "clue":"Warm bedding glows in amber light."}
]
const SPECIALTIES = [
	{"id":"balanced", "name":"A little of everything", "tag":"", "copy":"A welcoming start for every kind of guest."},
	{"id":"peaceful", "name":"Peaceful retreat", "tag":"quiet", "copy":"Quiet and warm rooms earn +4/min each. Quiet guests feel especially welcome."},
	{"id":"playful", "name":"Playful social club", "tag":"play", "copy":"Play and social rooms earn +4/min each. Playful guests feel especially welcome."},
	{"id":"gourmet", "name":"Food lovers' hotel", "tag":"food", "copy":"Kitchen upgrades earn +3/min each. Food enthusiasts feel especially welcome."}
]
const EVENTS = [
	{"id":"nap", "name":"Great Nap Championship", "tag":"quiet", "seconds":45, "hotel":-1, "copy":"Prepare quiet rooms and let your guests demonstrate competitive relaxation."},
	{"id":"cardboard", "name":"Cardboard Castle Festival", "tag":"explore", "seconds":50, "hotel":-1, "copy":"Boxes and towers turn your hotel into a tiny kingdom."},
	{"id":"lantern", "name":"Lantern Evening", "tag":"warm", "seconds":55, "hotel":-1, "copy":"Warm beds and lanterns make an evening worth remembering."},
	{"id":"beach", "name":"Seaside Friendship Picnic", "tag":"social", "seconds":50, "hotel":1, "copy":"Invite a travel club and prepare shared tables and welcome flowers."},
	{"id":"trail", "name":"Forest Treasure Trail", "tag":"explore", "seconds":50, "hotel":2, "copy":"Climbing rooms help explorers find woodland keepsakes."},
	{"id":"spa", "name":"Snowcap Slumber Spa", "tag":"warm", "seconds":50, "hotel":3, "copy":"Heated beds and soft lighting welcome snowbound travelers."}
]
const STAFF = [
	{"name":"Pippin", "job":"Concierge", "zone":3, "skills":["Gentle welcome","Travel club host"], "copy":"Shortens the time between guest visits. Skills welcome shy cats or social travelers."},
	{"name":"Saffron", "job":"Chef", "zone":1, "skills":["Comfort food","Tasting menu"], "copy":"Improves dining scores. Skills welcome quiet cats or food enthusiasts."},
	{"name":"Buttons", "job":"Room attendant", "zone":0, "skills":["Cloud pillows","Playful turndown"], "copy":"Improves room scores. Skills welcome warm-bed fans or playful guests."}
]
const PRODUCTS = [
	{"id":"purrington.cat_club", "name":"The Traveling Cat Club", "copy":"Truffle, Ember and Captain, with their own preferences, greetings and stories. Removes every ad.", "cats":[12,13,14], "hotels":[]},
	{"id":"purrington.forest_lodge", "name":"Forest Lodge", "copy":"A complete woodland hotel, treasure-trail event and Juniper the explorer. Removes every ad.", "cats":[16], "hotels":[2]},
	{"id":"purrington.snowcap_spa", "name":"Snowcap Spa", "copy":"A complete mountain hotel, slumber-spa event, Flurry and Pearl. Removes every ad.", "cats":[15,17], "hotels":[3]}
]
const HOTEL_THEMES = ["Garden retreat", "Coastal escape", "Woodland hideaway", "Mountain sanctuary"]
const HOTEL_MECHANICS = ["Sunshine combinations delight garden regulars.", "Social rooms and group picnics bring travelers together.", "Climbing rooms and treasure trails reward curious explorers.", "Warm rooms and spa evenings welcome winter travelers."]

static func find_item(id: String) -> Dictionary:
	for item in FURNITURE:
		if item.id == id:
			return item
	return {}

static func find_event(id: String) -> Dictionary:
	for item in EVENTS:
		if item.id == id:
			return item
	return {}

static func product(id: String) -> Dictionary:
	for item in PRODUCTS:
		if item.id == id:
			return item
	return {}

static func cat_pack(index: int) -> String:
	for item in PRODUCTS:
		if item.cats.has(index):
			return item.id
	return ""
