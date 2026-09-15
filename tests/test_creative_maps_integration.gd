extends SceneTree
## Exercise content through the actual placement model and walking graph.

const Model = preload("res://scripts/creative/creative_model.gd")
const Content = preload("res://scripts/creative/creative_content.gd")
const Geo = preload("res://scripts/creative/lot_geometry.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func close_model(model) -> void:
	model.social.model = null
	model.social = null

func test_starter_operation() -> void:
	var model = Model.new()
	model.new_game(1000)
	for index in range(4):
		var definition: Dictionary = model.map_definition(index)
		var arrival := Vector2(definition.arrival[0],definition.arrival[1])
		var reception_open := false
		var roles := {}
		for room in model.hotel(index).rooms:
			var status: Dictionary = model.room_status(room.id,index)
			check(status.ready,"Starter room operates immediately: %d/%s (%s)" % [index,room.id,status.status])
			var door := Geo.door(room)
			var route: Array = model.route(arrival,door,true,index)
			check(not route.is_empty() and Vector2(route[-1]).distance_to(door) < 0.45,"Constructed route reaches actual door: %d/%s" % [index,room.id])
		for venue in model.venues(index):
			check(venue.open,"Starter activity is reachable: %d/%s" % [index,venue.id])
			roles[venue.role] = true
			if venue.role == "reception" and venue.open: reception_open = true
		check(reception_open,"Every destination can check in guests")
		check(roles.has(["sun","bar","play","warm"][index]),"Destination has its intended themed activity")
		for path in definition.paths:
			var point := Vector2(path.x+0.5,path.y+0.5)
			check(Geo.point_owned(point,definition,model.hotel(index)),"Starter path is on owned land")
			var route: Array = model.route(arrival,point,true,index)
			check(not route.is_empty() and Vector2(route[-1]).distance_to(point) < 0.5,"Actual walking graph reaches every starter path tile")
	close_model(model)

func test_rotated_templates() -> void:
	for index in range(4):
		for arrangement in Content.templates():
			for rotation in range(4):
				var model = Model.new()
				model.new_game(1000)
				model.state.current_hotel = index
				model.state.coins = 100000
				model.hotel().owned = true
				model.hotel().rooms.clear()
				model.hotel().objects.clear()
				model.hotel().paths.clear()
				model._invalidate()
				var payload := {"template":arrangement.id,"x":-5,"y":-5,"rotation":rotation}
				var before: Dictionary = model.serialize()
				var quote: Dictionary = model.quote("place_template",payload)
				var label := "%s on map %d rotation %d" % [arrangement.id,index,rotation]
				check(quote.ok,"Template quote is geometrically valid: " + label + " / " + quote.message)
				check(model.serialize() == before,"Template quote leaves all pieces and wallet untouched")
				var expected_cost: int = arrangement.w * arrangement.h * 25
				for item in arrangement.objects: expected_cost += Content.item(item.item).cost
				check(is_equal_approx(quote.cost,expected_cost),"Template price totals its shell and actual furniture")
				var result: Dictionary = model.commit("place_template",payload)
				check(result.ok,"Template commits as editable pieces: " + label)
				if result.ok:
					check(model.hotel().rooms.size() == 1 and model.hotel().objects.size() == arrangement.objects.size(),"Template has one shell and individually selectable items")
					var room: Dictionary = model.hotel().rooms[0]
					var bounds := Geo.room_rect(room)
					for object in model.hotel().objects:
						check(object.room == room.id and bounds.grow(-0.1).encloses(Geo.object_rect(object)),"Rotated template preserves object membership and wall clearance: " + label)
				close_model(model)

func run() -> void:
	test_starter_operation()
	test_rotated_templates()
	print("CREATIVE MAPS INTEGRATION: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
