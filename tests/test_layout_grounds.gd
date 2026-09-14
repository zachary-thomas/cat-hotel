extends SceneTree
const Model = preload("res://scripts/core/hotel_model.gd")
const Grounds = preload("res://scripts/core/grounds_model.gd")
const Layout = preload("res://scripts/core/room_layout.gd")
const Neighborhood = preload("res://scripts/world/neighborhood.gd")
var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var m = Model.new()
	m.new_game(1000)
	m.hotels[0].layout = [{"kind":"regular","x":0,"y":9,"rotation":0},{"kind":"regular","x":6,"y":9,"rotation":2}]
	var data: Dictionary = m.grounds.hotels[0]
	data.dirty[0] = true
	check(m.grounds.perform(m,"clean",{"index":0}).ok,"A dirty placed room accepts a manager job")
	var endpoint: Vector2 = Vector2(data.job.path[-1][0],data.job.path[-1][1])
	check(endpoint.is_equal_approx(Vector2(-3.3,-6.05)),"Cleaning targets the placed room center, rather than the old lobby bed")
	check(_uses_room_route(data.job,m,0),"The clean job enters through the placed room's door")
	m.grounds.advance(float(data.job.travel)+1,m)
	var before: Dictionary = m.grounds.serialize()
	var before_layout: Array = m.hotels[0].layout.duplicate(true)
	m.hotels[0].wings = 1
	m.hotels[0].layout[0] = {"kind":"regular","x":0,"y":6,"rotation":1}
	m.grounds.layout_changed(m,0)
	var new_center: Vector2 = Grounds.room_spot(0,m,0)
	check(data.cleaned == 0 and data.dirty[0],"Moving an active cleaning room does not finish or reward stale work")
	check(data.job.elapsed == 0 and _endpoint(data.job).is_equal_approx(new_center),"Moving restarts the manager's clean job at the new room")
	check(_uses_room_route(data.job,m,0),"The moved job uses the rotated entrance")
	check(Grounds.valid_job(data.job),"Grid cleaning paths pass saved job validation")
	var saved: Dictionary = m.grounds.serialize()
	var reloaded_model = Model.new()
	check(reloaded_model.restore(m.serialize()),"The complete hotel save accepts a moved room with active cleaning")
	check(reloaded_model.hotels[0].layout == m.hotels[0].layout and reloaded_model.grounds.serialize() == saved,"A complete reload preserves the layout and exact active cleaning progress")
	var loaded = Grounds.new()
	check(loaded.restore(saved),"A moved room's active job survives save and reload")
	check(loaded.serialize() == saved,"Reload retains the precise path and work progress")
	loaded.advance(float(loaded.hotels[0].job.duration)+0.01,m)
	check(not loaded.hotels[0].dirty[0] and loaded.hotels[0].cleaned == 1,"Reloaded cleaning reaches the moved room and completes once")
	check(Vector2(loaded.hotels[0].manager[0],loaded.hotels[0].manager[1]).is_equal_approx(new_center),"The manager arrives at the moved room center")
	var earned: int = m.coins_units
	loaded.advance(0.01,m)
	check(m.coins_units == earned,"Completed cleaning cannot pay twice")
	check(m.grounds.restore(before),"A transaction rollback can restore the pre-move worker state")
	m.hotels[0].layout = before_layout
	check(m.grounds.serialize() == before,"Rollback restores cleaning reservations and elapsed work exactly")
	m.hotels[0].layout[0] = {"kind":"regular","x":0,"y":6,"rotation":1}
	data = m.grounds.hotels[0]
	data.job = {}
	data.manager = [0.0,3.5]
	data.maid = true
	data.maid_position = [0.0,3.5]
	m.grounds.advance(0.1,m)
	check(not data.maid_job.is_empty() and _endpoint(data.maid_job).is_equal_approx(new_center),"The maid targets the moved room")
	m.grounds.advance(float(data.maid_job.travel)+1,m)
	m.hotels[0].layout[0] = {"kind":"regular","x":0,"y":6,"rotation":0}
	m.grounds.layout_changed(m,0)
	check(data.dirty[0] and data.maid_job.elapsed == 0 and _uses_room_route(data.maid_job,m,0),"Moving during housekeeping safely reassigns through the new door")
	loaded = Grounds.new()
	check(loaded.restore(m.grounds.serialize()),"An automatically replanned maid job survives reload")
	loaded.advance(float(loaded.hotels[0].maid_job.duration)+0.01,m)
	check(not loaded.hotels[0].dirty[0] and loaded.hotels[0].cleaned == 1,"Reloaded housekeeping completes the moved room exactly once")
	var departure: Array = Grounds.route(Grounds.room_spot(0,m,0),Grounds.BUSH_SPOTS[0],m,0)
	var door_path: Array = Layout.route(m,0,0)
	check(departure.has(door_path[-2]),"An outdoor job exits the room through its door")
	check(Grounds.walkable(Vector2(-0.55,-8.25),1,m,0),"Manager walks can target reachable new corridors")
	check(not Grounds.walkable(Vector2(0,-15),1,m,0),"Manager walks cannot enter locked floor space")
	var many_points: Dictionary = data.maid_job.duplicate(true)
	while many_points.path.size() <= 16:
		many_points.path.insert(1,many_points.path[0].duplicate())
	check(Grounds.valid_job(many_points),"Longer grid paths remain valid saves")
	many_points.path[0][0] = INF
	check(not Grounds.valid_job(many_points),"Extended path bounds still reject invalid coordinates")
	var neighborhood = Neighborhood.new()
	neighborhood.sync(m)
	var marker_before: Vector3 = _clean_marker(neighborhood,0)
	m.hotels[0].layout[0].x = 1
	neighborhood.sync(m)
	var marker_after: Vector3 = _clean_marker(neighborhood,0)
	check(not marker_after.is_equal_approx(marker_before) and is_equal_approx(marker_after.x,Grounds.room_spot(0,m,0).x),"Dirty markers follow a move even when room count and dirty flags are unchanged")
	neighborhood.free()
	var legacy_model = Model.new()
	legacy_model.new_game(1000)
	legacy_model.grounds.hotels[0].dirty[0] = true
	legacy_model.grounds.hotels[0].job = Grounds.make_job("clean",0,Grounds.MANAGER_HOME,Grounds.room_spot(0),5)
	var legacy: Dictionary = legacy_model.serialize()
	for hotel in legacy.hotels:
		hotel.erase("layout")
	check(reloaded_model.restore(legacy),"A legacy save with active cleaning migrates")
	check(_endpoint(reloaded_model.grounds.hotels[0].job).is_equal_approx(Grounds.room_spot(0,reloaded_model,0)),"Legacy cleaning is replanned toward the migrated room instead of the vanished bed")
	print("LAYOUT GROUNDS TESTS: ","PASS" if failures == 0 else "FAIL"," (",failures," failures)")
	quit(1 if failures else 0)

func _endpoint(job: Dictionary) -> Vector2:
	return Vector2(job.path[-1][0],job.path[-1][1])

func _uses_room_route(job: Dictionary, model, room: int) -> bool:
	var points: Array = Layout.route(model,0,room)
	if points.is_empty():
		return false
	for p in points:
		var found: bool = false
		for packed in job.path:
			if Vector2(packed[0],packed[1]).is_equal_approx(p):
				found = true
				break
		if not found:
			return false
	return true

func _clean_marker(neighborhood, room: int) -> Vector3:
	for target in neighborhood.targets:
		if target.action == "clean" and int(target.payload.index) == room:
			return target.position
	return Vector3(INF,INF,INF)
