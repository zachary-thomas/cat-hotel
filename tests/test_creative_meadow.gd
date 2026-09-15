extends SceneTree
## A first visit should read as one welcoming hotel and a usable planted garden.
const Model=preload("res://scripts/creative/creative_model.gd")
const Geo=preload("res://scripts/creative/lot_geometry.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void:
	var model=Model.new(); model.new_game(1000)
	var map: Dictionary=model.map_definition()
	check(map.has("road"),"Meadow has an authored arrival road")
	if map.has("road"):
		var road:=Geo.rect(map.road.rect)
		check(not road.intersects(Geo.rect(map.base)),"Scenic road stays outside building land")
		for plot in map.plots: check(not road.intersects(Geo.rect(plot.rect)),"Scenic road never consumes expansion land")
	var connected: Dictionary={str(map.rooms[0].id):true}
	for iteration in range(map.rooms.size()):
		for room in map.rooms:
			for neighbor in map.rooms:
				if connected.has(str(neighbor.id)) and Geo.room_rect(room).grow(0.01).intersects(Geo.room_rect(neighbor)): connected[str(room.id)]=true
	check(connected.size()==map.rooms.size(),"Meadow starts as a connected main hotel")
	var outdoor:=0; var flowers:=0; var fountain:=false
	for object in map.objects:
		check(not str(object.item).contains("sofa"),"Starter hotel has no couches")
		if object.room=="": outdoor+=1
		if object.item=="flower_bed": flowers+=1
		if object.item=="fountain": fountain=true
	check(outdoor>=24 and flowers>=6 and fountain,"First garden has layered planting and a fountain")
	check(model.guest_capacity()==4,"Two starter guest rooms retain four guest places")
	for room in model.hotel().rooms: check(model.room_status(str(room.id)).ready,"Connected room opens: "+str(room.id))
	var reception: Vector2
	for venue in model.venues():
		if venue.role=="reception":
			check(venue.open,"Reception is operational in the main hotel")
			reception=Vector2(venue.x,venue.y)
	for room in model.hotel().rooms:
		if room.kind!="regular": continue
		check(not model.route(Geo.door(room),reception,true).is_empty(),"Guest doors connect to the actual reception")
	var reopened=Model.new()
	check(reopened.restore(model.serialize()),"Detailed starter hotel saves and reopens")
	print("CREATIVE MEADOW: ",failures," failures")
	quit(1 if failures else 0)
