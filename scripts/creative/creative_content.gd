extends RefCounted
## One catalogue for placement, prices, guest activities, world art and thumbnails.
## Sizes are unrotated lot units; legacy furniture keeps its original half-cell footprint.

# id, name, category, cost, size, color, tags, surfaces, role, capacity, service
const CATALOGUE := [
	["mat","Linen mat","Furniture",0,[1.5,2.0],"d4b698",[],["indoor","outdoor"],"bed",1,0],
	["sun_cushion","Sunshine cushion","Furniture",120,[1.5,2.0],"edc76a",["sunny"],["indoor","outdoor"],"bed",1,0],
	["cave","Sheltered cat bed","Furniture",180,[1.5,2.0],"a892b9",["quiet"],["indoor"],"bed",1,0],
	["heated","Heated cloud bed","Furniture",320,[1.5,2.0],"e59889",["warm"],["indoor"],"bed",1,0],
	["box","Delivery box","Furniture",0,[1.0,1.0],"bb8b5e",["explore"],["indoor","outdoor"],"play",1,2],
	["perch","Window perch","Furniture",150,[1.0,1.0],"92bdb2",["sunny"],["indoor","outdoor"],"sun",1,2],
	["tunnel","Play tunnel","Furniture",190,[1.5,1.0],"c295c0",["play"],["indoor","outdoor"],"play",1,2],
	["tower","Climbing tower","Furniture",260,[1.0,1.0],"83aa92",["explore","play"],["indoor","outdoor"],"play",2,2],
	["table","Picnic table","Furniture",250,[1.0,1.5],"b98964",["food","social"],["indoor","outdoor"],"seat",2,1],
	["plant","Leafy planter","Furniture",0,[0.5,0.5],"80a86e",[],["indoor","outdoor"],"decoration",0,-1],
	["rug","Whisper-soft rug","Furniture",110,[2.0,1.0],"bdaca6",["quiet"],["indoor"],"decoration",0,-1],
	["scratch","Rope scratcher","Furniture",140,[0.5,1.0],"bd9a6e",["play"],["indoor","outdoor"],"play",1,2],
	["lamp","Amber lantern","Furniture",230,[0.5,0.5],"e7b868",["warm"],["indoor","outdoor"],"decoration",0,-1],
	["flowers","Welcome flowers","Furniture",160,[0.5,0.5],"dc92a1",["social"],["indoor","outdoor"],"decoration",0,-1],
	["blanket","Friendship blanket","Furniture",0,[1.5,2.0],"ca9eae",["quiet","warm"],["indoor","outdoor"],"bed",1,0],
	["cloud_sofa","Cloud sofa","Furniture",420,[1.5,1.0],"bed5dc",["social","warm"],["indoor"],"seat",2,2],
	["adventure_tree","Adventure tree","Furniture",650,[1.5,1.5],"93b98a",["explore","play"],["indoor","outdoor"],"play",3,2],
	["canopy_bed","Canopy bed","Furniture",900,[2.0,2.0],"d7b5c4",["quiet"],["indoor"],"bed",1,0],
	["reception_counter","Welcome counter","Furniture",240,[3.0,1.0],"87b7a5",["social"],["indoor"],"reception",2,3],
	["milkshake_counter","Milkshake counter","Furniture",240,[3.0,1.0],"e6a1a6",["food","social"],["indoor","outdoor"],"bar",3,1],
	["cafe_stool","Café stool","Furniture",45,[0.5,0.5],"d89a87",["food","social"],["indoor","outdoor"],"seat",1,1],
	["cafe_table","Café table","Furniture",90,[1.5,1.5],"c29b73",["food","social"],["indoor","outdoor"],"seat",2,1],
	["lounge_sofa","Lounge sofa","Furniture",180,[2.5,1.5],"a8b7cd",["quiet","social"],["indoor","outdoor"],"seat",3,2],
	["fireplace","Fireside hearth","Furniture",220,[2.0,1.0],"bc8b6d",["quiet","warm"],["indoor","outdoor"],"warm",2,2],
	["garden_planter","Garden planter","Outdoors",30,[1.0,1.0],"ba846e",["quiet"],["outdoor"],"decoration",0,-1],
	["shrub","Round shrub","Outdoors",35,[1.0,1.0],"6d986c",["quiet"],["outdoor"],"decoration",0,-1],
	["flower_bed","Flower bed","Outdoors",40,[2.0,1.0],"dd929f",["social"],["outdoor"],"decoration",0,-1],
	["garden_lamp","Garden lamp","Outdoors",70,[0.5,0.5],"e2b868",["warm"],["outdoor"],"decoration",0,-1],
	["bench","Garden bench","Outdoors",90,[2.0,1.0],"b59066",["sunny","social"],["outdoor"],"seat",2,2],
	["tree","Shade tree","Outdoors",100,[2.0,2.0],"78a776",["explore","quiet"],["outdoor"],"decoration",0,-1],
	["cat_statue","Little cat statue","Outdoors",120,[1.0,1.0],"b4b7b2",["explore"],["outdoor"],"decoration",0,-1],
	["fountain","Paw fountain","Outdoors",200,[2.0,2.0],"89b9c3",["quiet"],["outdoor"],"decoration",0,-1],
	["fence","Picket fence","Outdoors",10,[2.0,0.5],"eee2c8",[],["outdoor"],"fence",0,-1],
	["gate","Garden gate","Outdoors",30,[2.0,0.5],"d9c59f",[],["outdoor"],"gate",0,-1],
	["pool","Kitty splash pool","Outdoors",250,[3.0,3.0],"89c5d6",["sunny","play"],["outdoor"],"amenity",3,2],
	["litter","Private litter nook","Outdoors",120,[2.0,2.0],"bda894",["quiet"],["outdoor"],"amenity",1,-1],
	["playpen","Rainbow playpen","Outdoors",350,[3.0,3.0],"a6bc8b",["play","explore"],["outdoor"],"amenity",3,2],
	["picnic","Catnip picnic garden","Outdoors",450,[3.0,3.0],"a4bc8c",["food","social"],["outdoor"],"amenity",4,1],
]

const ARRANGEMENTS := [
	{"id":"lobby","name":"Welcoming lobby","description":"A welcome counter, a soft waiting sofa and a table for new friends.","kind":"shared","w":6,"h":6,"tags":["social"],"objects":[
		{"item":"reception_counter","x":0.5,"y":0.5,"rotation":0},
		{"item":"lounge_sofa","x":0.5,"y":3.5,"rotation":0},
		{"item":"cafe_table","x":3.5,"y":3.5,"rotation":0},
		{"item":"flowers","x":4.5,"y":0.5,"rotation":0},
		{"item":"rug","x":0.5,"y":2.0,"rotation":0}]},
	{"id":"milkshake","name":"Milkshake café","description":"A pastel counter, little stools and café tables for a shared treat.","kind":"shared","w":8,"h":6,"tags":["food","social"],"objects":[
		{"item":"milkshake_counter","x":0.5,"y":0.5,"rotation":0},
		{"item":"cafe_stool","x":0.5,"y":2.5,"rotation":0},
		{"item":"cafe_stool","x":1.5,"y":2.5,"rotation":0},
		{"item":"cafe_stool","x":2.5,"y":2.5,"rotation":0},
		{"item":"cafe_table","x":4.5,"y":0.5,"rotation":0},
		{"item":"lounge_sofa","x":0.5,"y":4.0,"rotation":0},
		{"item":"cafe_table","x":4.5,"y":4.0,"rotation":0},
		{"item":"flowers","x":6.5,"y":0.5,"rotation":0},
		{"item":"lamp","x":6.5,"y":4.5,"rotation":0}]},
	{"id":"lounge","name":"Fireside lounge","description":"Face-to-face sofas and an amber hearth for quiet company.","kind":"shared","w":8,"h":6,"tags":["quiet","warm","social"],"objects":[
		{"item":"lounge_sofa","x":0.5,"y":0.5,"rotation":0},
		{"item":"lounge_sofa","x":0.5,"y":4.0,"rotation":2},
		{"item":"fireplace","x":4.5,"y":0.5,"rotation":0},
		{"item":"rug","x":3.5,"y":2.5,"rotation":0},
		{"item":"cafe_table","x":4.5,"y":4.0,"rotation":0},
		{"item":"lamp","x":6.5,"y":4.5,"rotation":0},
		{"item":"plant","x":6.5,"y":0.5,"rotation":0}]},
	{"id":"play","name":"Adventure playroom","description":"A climbing tree, tunnel and cozy sidelines for little explorers.","kind":"shared","w":8,"h":6,"tags":["play","explore","social"],"objects":[
		{"item":"adventure_tree","x":0.5,"y":0.5,"rotation":0},
		{"item":"tunnel","x":3.5,"y":0.5,"rotation":0},
		{"item":"box","x":5.5,"y":0.5,"rotation":0},
		{"item":"scratch","x":3.5,"y":4.0,"rotation":0},
		{"item":"cloud_sofa","x":0.5,"y":4.0,"rotation":0},
		{"item":"tower","x":5.0,"y":4.0,"rotation":0},
		{"item":"plant","x":6.5,"y":4.5,"rotation":0}]},
	{"id":"sunroom","name":"Sunbeam sitting room","description":"Golden cushions, sunny perches and a leafy corner to watch the world.","kind":"shared","w":8,"h":6,"tags":["sunny","quiet","social"],"objects":[
		{"item":"sun_cushion","x":0.5,"y":0.5,"rotation":0},
		{"item":"perch","x":4.5,"y":0.5,"rotation":0},
		{"item":"lounge_sofa","x":0.5,"y":4.0,"rotation":0},
		{"item":"cafe_table","x":4.5,"y":4.0,"rotation":0},
		{"item":"flowers","x":6.5,"y":0.5,"rotation":0},
		{"item":"plant","x":6.5,"y":4.5,"rotation":0}]},
	{"id":"terrace","name":"Garden terrace","description":"An open-air café with a milkshake counter, bench and fresh flowers.","kind":"terrace","w":8,"h":6,"tags":["sunny","food","social"],"objects":[
		{"item":"milkshake_counter","x":0.5,"y":0.5,"rotation":0},
		{"item":"cafe_stool","x":0.5,"y":2.5,"rotation":0},
		{"item":"cafe_stool","x":2.0,"y":2.5,"rotation":0},
		{"item":"bench","x":0.5,"y":4.5,"rotation":0},
		{"item":"cafe_table","x":4.5,"y":4.0,"rotation":0},
		{"item":"garden_planter","x":5.5,"y":0.5,"rotation":0},
		{"item":"garden_lamp","x":6.5,"y":4.5,"rotation":0}]},
]

static func item(id: String) -> Dictionary:
	for row in CATALOGUE:
		if row[0] != id: continue
		var result := {"id":row[0],"name":row[1],"category":row[2],"cost":row[3],"size":row[4].duplicate(),"color":row[5],"shape":row[0],"tags":row[6].duplicate(),"surfaces":row[7].duplicate(),"role":row[8],"capacity":row[9],"service":row[10]}
		if id == "blanket": result["bond"] = 20
		return result
	return {}

static func items(category: String = "") -> Array:
	var result := []
	for row in CATALOGUE:
		if category.is_empty() or row[2] == category: result.append(item(row[0]))
	return result

static func templates() -> Array:
	return ARRANGEMENTS.duplicate(true)

static func template(id: String) -> Dictionary:
	for arrangement in ARRANGEMENTS:
		if arrangement.id == id: return arrangement.duplicate(true)
	return {}
