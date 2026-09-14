extends SceneTree

const Model = preload("res://scripts/core/hotel_model.gd")
const Grounds = preload("res://scripts/core/grounds_model.gd")
const Shared = preload("res://scripts/core/shared_layout.gd")
const Catalog = preload("res://scripts/core/furniture_catalog.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var model := Model.new(); model.new_game(1000)
	var plant_uid := ""
	for value in model.furniture.room_items(0,0):
		if value.item == "plant": plant_uid=value.uid
	var placed: Dictionary = {}
	for y in range(18,24):
		for x in range(8,12):
			var attempt: Dictionary = model.furniture.transfer(model,0,0,-2,plant_uid,x,y,0)
			if attempt.ok:
				placed={"x":x,"y":y}; break
		if not placed.is_empty(): break
	check(not placed.is_empty(),"Fixture finds a valid guest-floor aisle furnishing position")
	if not placed.is_empty():
		var center3 := Shared.local_to_world(Vector2(placed.x,placed.y)+Vector2(0.5,0.5)); var center := Vector2(center3.x,center3.z)
		check(not Grounds.walkable(center,model.wing_count(0),model,0),"Manual manager targets reject the occupied shared-furniture cell")
		check(not model.grounds.perform(model,"walk",{"x":center.x,"z":center.y}).ok,"Manager walk commands reject unreachable furniture targets")
		var definition := Catalog.item("plant"); var cells: Array[Vector2i] = Shared._footprint({"item":"plant","x":placed.x,"y":placed.y,"rotation":0},definition)
		var obstacle: Rect2 = Shared._cell_rect(cells[0]).grow(Shared.ACTOR_CLEARANCE)
		var path: Array = []
		for y in range(18,24):
			for x in range(8,12):
				var target3 := Shared.local_to_world(Vector2(x,y)+Vector2(0.5,0.5))
				path = Grounds.route(Grounds.MANAGER_HOME,Vector2(target3.x,target3.z),model,0)
				if not path.is_empty(): break
			if not path.is_empty(): break
		check(not path.is_empty(),"Shared furniture preserves at least one radius-safe guest-floor aisle target")
		for index in range(1,path.size()):
			check(not Grounds._segment_intersects_rect(Vector2(path[index-1]),Vector2(path[index]),obstacle),"Every manager path segment clears the furniture footprint by the actor radius")
	var room_target := Grounds.room_spot(0,model,0)
	check(not Grounds.route(Grounds.MANAGER_HOME,room_target,model,0).is_empty(),"Guest-room housekeeping routing remains available")
	quit(1 if failures else 0)
