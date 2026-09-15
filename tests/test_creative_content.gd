extends SceneTree
## Content placement checks catch blocked doors and authored overlaps before a map ships.

var failures := 0
var content: Script
var maps: Script

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for path in ["res://scripts/creative/creative_content.gd", "res://scripts/creative/creative_maps.gd"]:
		check(FileAccess.file_exists(path), "Creative catalogue and four authored destinations must exist: " + path)
	if failures:
		quit(1)
		return
	content = load("res://scripts/creative/creative_content.gd")
	maps = load("res://scripts/creative/creative_maps.gd")
	call_deferred("run")

func footprint(value: Dictionary, is_room: bool = false) -> Rect2:
	var dimensions: Array = [value.w,value.h] if is_room else content.item(value.item).size
	var size := Vector2(dimensions[0],dimensions[1])
	if int(value.get("rotation",0)) % 2: size = Vector2(size.y,size.x)
	return Rect2(Vector2(value.x,value.y),size)

func check_objects(objects: Array, rooms: Array, label: String) -> void:
	var ids := {}
	for i in range(objects.size()):
		var object: Dictionary = objects[i]
		var item: Dictionary = content.item(object.item)
		check(not item.is_empty(), label + " references a real item: " + str(object.item))
		if item.is_empty(): continue
		check(not ids.has(object.id), label + " object IDs are unique")
		ids[object.id] = true
		var rect := footprint(object)
		for coordinate in [object.x,object.y]:
			check(is_equal_approx(coordinate * 2,round(coordinate * 2)), label + " objects use half-cell snapping")
		if object.room != "":
			var matched := false
			for room in rooms:
				if room.id != object.room: continue
				matched = true
				var shell := footprint(room,true)
				check(shell.grow(-0.1).encloses(rect), label + " item is inside room walls: " + object.id)
				check(item.surfaces.has("outdoor" if room.kind == "terrace" else "indoor"), label + " item supports its surface: " + object.id)
				var door_apron := Rect2(Vector2(shell.end.x - 1,shell.get_center().y - 1),Vector2(1,2))
				check(not rect.intersects(door_apron), label + " door remains clear: " + object.id)
			check(matched,label + " object has a real room")
		else:
			check(item.surfaces.has("outdoor"),label + " garden object supports outdoors")
			for room in rooms:
				check(not rect.intersects(footprint(room,true)),label + " outside object stays outside rooms: " + object.id)
		for j in range(i):
			check(not rect.intersects(footprint(objects[j])),label + " furniture does not overlap: " + object.id + "/" + objects[j].id)

func test_catalogue() -> void:
	var prices := {"mat":0,"sun_cushion":120,"cave":180,"heated":320,"box":0,"perch":150,"tunnel":190,"tower":260,"table":250,"plant":0,"rug":110,"scratch":140,"lamp":230,"flowers":160,"blanket":0,"cloud_sofa":420,"adventure_tree":650,"canopy_bed":900,"pool":250,"litter":120,"playpen":350,"picnic":450,"garden_planter":30,"shrub":35,"flower_bed":40,"garden_lamp":70,"bench":90,"tree":100,"cat_statue":120,"fountain":200,"fence":10,"gate":30,"reception_counter":240,"milkshake_counter":240,"cafe_stool":45,"cafe_table":90,"lounge_sofa":180,"fireplace":220}
	for id in prices:
		check(content.item(id).get("cost",-1) == prices[id],"Approved earned-coin price for " + id)
	var ids := {}
	for item in content.items():
		check(not ids.has(item.id),"Catalogue identifiers are unique")
		ids[item.id] = true
		for field in ["name","category","cost","size","color","shape","tags","surfaces","role","capacity","service"]:
			check(item.has(field),"Item includes renderer/simulation field " + item.id + "/" + field)
		check(item.category in ["Furniture","Outdoors"],"Supported catalogue category")
		check(item.service >= -1 and item.service <= 3,"Known service association")
		check(item.size.size() == 2 and item.size[0] > 0 and item.size[1] > 0,"Usable item footprint")
		check(Color.html_is_valid(item.color),"Drawable item color")
		for dimension in item.size:
			check(is_equal_approx(dimension * 2,round(dimension * 2)),"Catalogue dimensions align to half cells")
	check(content.item("mat").role == "bed","Starter mat makes a guest room sleepable")
	check(content.item("reception_counter").capacity > 0,"Reception can receive guests")
	check(content.item("milkshake_counter").service == 1,"Milkshake service responds to kitchen upgrades")
	check(content.items("Furniture").size() + content.items("Outdoors").size() == content.items().size(),"Catalogue filters retain all items")
	check(content.item("missing").is_empty() and content.items("missing").is_empty(),"Unknown catalogue selections fail safely")
	var isolated: Dictionary = content.item("mat")
	isolated.size[0] = 999
	check(content.item("mat").size[0] == 1.5,"Catalogue callers cannot corrupt shared footprints")

func test_templates() -> void:
	for id in ["lobby","milkshake","lounge","play","sunroom","terrace"]:
		var arrangement: Dictionary = content.template(id)
		check(not arrangement.is_empty(),"Editable venue template exists: " + id)
		if arrangement.is_empty(): continue
		check(arrangement.kind in ["shared","terrace"],"Venue has a supported shell")
		check(arrangement.objects.size() >= 4,"Venue has individually editable pieces")
		var room := {"id":"template","x":0,"y":0,"w":arrangement.w,"h":arrangement.h,"rotation":0,"kind":arrangement.kind}
		var objects := []
		for i in range(arrangement.objects.size()):
			var object: Dictionary = arrangement.objects[i].duplicate(true)
			object.id = "piece_%d" % i
			object.room = "template"
			objects.append(object)
		check_objects(objects,[room],"Template " + id)
	check(content.template("missing").is_empty(),"Unknown template is rejected")

func test_destinations() -> void:
	var names := ["Meadow House","Seaside Suites","Forest Lodge","Snowcap Spa"]
	var signatures := {}
	for index in range(4):
		var map: Dictionary = maps.definition(index)
		check(map.name == names[index],"Destination identity is retained")
		var base := Rect2(map.base[0],map.base[1],map.base[2],map.base[3])
		check(map.rooms.filter(func(room): return room.kind == "regular").size() == 2,"Each map starts with two guest rooms")
		check(map.rooms.size() >= 4,"Each map has a lobby and themed venue")
		check(map.scenery.size() >= 8,"Each map has an authored environment")
		var rects := [base]
		for plot in map.plots:
			check(plot.cost == (1000 if plot.id == "north" else 750),"Parcel price is retained")
			var rect := Rect2(plot.rect[0],plot.rect[1],plot.rect[2],plot.rect[3])
			check(base.grow(0.01).intersects(rect),"Expansion plot touches starter land")
			for other in rects:
				check(not other.intersects(rect),"Land parcels do not overlap")
			rects.append(rect)
		check(map.plots.size() == 3,"All destinations have three parcels")
		for i in range(map.rooms.size()):
			var room: Dictionary = map.rooms[i]
			check(base.encloses(footprint(room,true)),"Room fits owned starter land")
			for j in range(i):
				check(not footprint(room,true).intersects(footprint(map.rooms[j],true)),"Starter rooms do not overlap")
		check_objects(map.objects,map.rooms,map.name)
		var reception := false
		for object in map.objects:
			check(base.encloses(footprint(object)),"Object fits owned starter land")
			if content.item(object.item).role == "reception": reception = true
		check(reception,"Every destination has an operational reception counter")
		var paths := {}
		for path in map.paths:
			var cell := Vector2i(path.x,path.y)
			check(not paths.has(cell),"Path cells have no duplicate prices")
			paths[cell] = true
			var tile := Rect2(Vector2(cell),Vector2.ONE)
			check(base.encloses(tile),"Path remains on owned starter land")
			for room in map.rooms:
				check(not tile.intersects(footprint(room,true)),"Exterior paths stay outside room shells")
			for object in map.objects:
				check(not tile.intersects(footprint(object)),"Path stays clear of furniture")
		var arrival := Vector2i(floori(map.arrival[0]),floori(map.arrival[1]))
		check(paths.has(arrival),"Arrival is on the built path")
		var visited := {arrival:true}
		var queue := [arrival]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_front()
			for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = cell + step
				if paths.has(next) and not visited.has(next):
					visited[next] = true
					queue.append(next)
		check(visited.size() == paths.size(),"All path segments connect to arrival")
		for cell in paths:
			var broad := false
			for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.UP,Vector2i(-1,-1)]:
				var corner: Vector2i = cell + offset
				if paths.has(corner) and paths.has(corner + Vector2i.RIGHT) and paths.has(corner + Vector2i.DOWN) and paths.has(corner + Vector2i.ONE): broad = true
			check(broad,"Starter circulation is two cells wide")
		for room in map.rooms:
			var rect := footprint(room,true)
			var door := Vector2i(roundi(rect.end.x),floori(rect.get_center().y))
			var internal_door := false
			for neighbor in map.rooms:
				if neighbor.id!=room.id and neighbor.kind=="shared" and footprint(neighbor,true).has_point(Vector2(rect.end.x+0.25,rect.get_center().y)): internal_door=true
			check(internal_door or (visited.has(door) and visited.has(door + Vector2i.UP)),"Each room doorway meets a shared interior or connected path: " + room.id)
		var signature := JSON.stringify(map.rooms)
		check(not signatures.has(signature),"Destinations have distinct authored layouts")
		signatures[signature] = true
		check(JSON.parse_string(JSON.stringify(map)) is Dictionary,"Map definitions remain save-compatible")
	var isolated: Dictionary = maps.definition(0)
	isolated.rooms.clear()
	check(maps.definition(0).rooms.size() >= 4,"Map edits cannot corrupt future starter layouts")
	check(maps.definition(-1).is_empty() and maps.definition(4).is_empty(),"Invalid destination is rejected")

func run() -> void:
	test_catalogue()
	test_templates()
	test_destinations()
	print("CREATIVE CONTENT: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
