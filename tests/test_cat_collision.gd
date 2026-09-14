extends SceneTree
const Cat = preload("res://scripts/world/voxel_cat.gd")
var failures: int = 0
var stage: Node3D

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func cat_at(start: Vector3, target: Vector3, size: float = 1.12):
	var cat = Cat.new()
	stage.add_child(cat)
	cat.build(Color("dc9e57"))
	cat.scale = Vector3.ONE * size
	cat.set_routine([{"position":start,"wait":0.0},{"position":target,"wait":1000.0}])
	cat.set_process(false)
	return cat

func reset_stage() -> void:
	if is_instance_valid(stage):
		stage.free()
	stage = Node3D.new()
	root.add_child(stage)

func run() -> void:
	reset_stage()
	var guarded = cat_at(Vector3.ZERO,Vector3(2,0,0))
	guarded.movement_guard = func(start: Vector3, finish: Vector3): return finish.x <= 0.45
	for frame in range(120): guarded._process(1.0/60.0)
	check(guarded.position.x <= 0.45,"An optional swept-center guard contains interior movement while default collision scale stays unchanged")
	# Straight movement used to let two cats walk through each other.
	for step in [1.0/60.0, 0.2]:
		reset_stage()
		var a = cat_at(Vector3(-3,0.24,0),Vector3(3,0.24,0))
		var b = cat_at(Vector3(3,0.24,0),Vector3(-3,0.24,0))
		var closest: float = INF
		for frame in range(ceili(18.0/step)):
			a._process(step)
			b._process(step)
			closest = minf(closest,a.position.distance_to(b.position))
		check(closest >= 1.20,"Oncoming cats keep body clearance, including at low frame rates (closest: %s)" % closest)
		check(a.position.distance_to(Vector3(3,0.24,0)) < 0.03 and b.position.distance_to(Vector3(-3,0.24,0)) < 0.03,"Oncoming cats pass each other and finish their routes (%s, %s)" % [a.position,b.position])
	reset_stage()
	var a = cat_at(Vector3(-3,0.24,0),Vector3(3,0.24,0))
	var b = cat_at(Vector3(0,0.24,-3),Vector3(0,0.24,3),1.35)
	var closest: float = INF
	for frame in range(1200):
		a._process(1.0/60.0)
		b._process(1.0/60.0)
		closest = minf(closest,a.position.distance_to(b.position))
	check(closest >= 1.30,"Crossing cats account for their different body sizes (closest: %s)" % closest)
	check(a.waypoint == 1 and not a.moving and b.waypoint == 1 and not b.moving,"Crossing traffic does not deadlock")
	reset_stage()
	a = cat_at(Vector3.ZERO,Vector3.ZERO)
	b = cat_at(Vector3.ZERO,Vector3(4,0,0))
	check(a.position.distance_to(b.position) >= 1.20,"Cats arriving at the same spawn point start in separate spaces")
	reset_stage()
	a = cat_at(Vector3(-3,0,0),Vector3.ZERO)
	b = cat_at(Vector3.ZERO,Vector3.ZERO)
	b.motion_enabled = false
	for frame in range(600):
		a._process(1.0/60.0)
	check(a.position.distance_to(b.position) >= 1.20,"An occupied destination makes the approaching cat wait outside the resting cat")
	check(a.body.position.y == 0.0 and a.legs[0].rotation.x == 0.0,"Waiting for space stops the walking animation")
	b.hide()
	for frame in range(300):
		a._process(1.0/60.0)
	check(a.position.distance_to(Vector3.ZERO) < 0.03,"Hidden cats do not block traffic and a waiting cat resumes when space clears")
	reset_stage()
	a = cat_at(Vector3(-3,0,0),Vector3(3,0,0))
	b = cat_at(Vector3(0,2,0),Vector3(0,2,0))
	for frame in range(600):
		a._process(1.0/60.0)
	check(a.position.distance_to(Vector3(3,0,0)) < 0.03 and absf(a.position.z) < 0.001,"A cat on a high perch does not block a cat on the ground")
	reset_stage()
	a = cat_at(Vector3(0,2,0),Vector3.ZERO)
	b = cat_at(Vector3.ZERO,Vector3.ZERO)
	for frame in range(10):
		a._process(1.0)
	check(a.position.y >= 0.93,"A descending cat waits before entering the body of a cat underneath it")
	reset_stage()
	a = cat_at(Vector3(7,0,0),Vector3(10,0,0))
	b = cat_at(Vector3(10,0,0),Vector3(10,0,0))
	var amenity = Node3D.new()
	stage.add_child(amenity)
	amenity.position = Vector3(10,0,0)
	b.reparent(amenity)
	for frame in range(600):
		a._process(1.0/60.0)
	check(a.global_position.distance_to(b.global_position) >= 1.20,"Cats inside translated amenity roots block guests in world coordinates")
	reset_stage()
	var model = preload("res://scripts/core/hotel_model.gd").new()
	model.new_game(1000)
	var world = preload("res://scripts/world/hotel_world.gd").new()
	stage.add_child(world)
	world.apply_life(model)
	world.set_process(false)
	world.neighborhood.set_process(false)
	for actor in get_nodes_in_group(&"navigating_cats"):
		actor.set_process(false)
	var manager = world.neighborhood.manager
	var resting = world.get_cat(2)
	resting.position = Vector3(0,0.24,5.0)
	manager.position = Vector3(0,0.24,7.0)
	model.grounds.hotels[0].manager = [0.0,5.0]
	for frame in range(240):
		world.neighborhood._process(1.0/60.0)
	check(manager.position.distance_to(resting.position) >= 1.30,"The model-driven manager cannot walk into a resting guest")
	world.react_cat(0,"friendship",1)
	check(world.get_cat(0).position.distance_to(world.get_cat(1).position) >= 1.40,"A friendship scene leaves room for both cats' head-bump animations")
	reset_stage()
	model = preload("res://scripts/core/hotel_model.gd").new()
	model.new_game(1000)
	model.life.sync_discoveries(12)
	model.grounds.hotels[0].maid = true
	model.grounds.hotels[0].amenities = ["pool","litter","playpen","picnic"]
	world = preload("res://scripts/world/hotel_world.gd").new()
	stage.add_child(world)
	world.apply_life(model)
	for index in range(12):
		world.ensure_cat(index)
	world.set_process(false)
	world.neighborhood.set_process(false)
	var cast: Array = get_nodes_in_group(&"navigating_cats")
	for actor in cast:
		actor.set_process(false)
	var overlaps: int = 0
	var arrivals_blocked: int = 0
	for frame in range(1800):
		world._process(1.0/30.0)
		world.neighborhood._process(1.0/30.0)
		for actor in cast:
			actor._process(1.0/30.0)
		if frame >= 1500:
			for index in range(3,12):
				var guest = world.get_cat(index)
				if guest.moving and not guest.walking and guest.reaction == "":
					arrivals_blocked += 1
		for i in range(cast.size()):
			for j in range(i+1,cast.size()):
				var first = cast[i]
				var second = cast[j]
				if not first.is_visible_in_tree() or not second.is_visible_in_tree():
					continue
				if absf(first.global_position.y-second.global_position.y) > 0.5:
					continue
				var offset: Vector3 = first.global_position-second.global_position
				if Vector2(offset.x,offset.z).length() < 1.20:
					overlaps += 1
	check(overlaps == 0,"A populated hotel with guests, staff, walkers and amenities stays separated for a full minute (%s overlaps)" % overlaps)
	check(arrivals_blocked < 900,"Waiting guests keep circulating instead of forming a permanent entrance jam (%s blocked frames)" % arrivals_blocked)
	if DisplayServer.get_name() != "headless":
		world.focus_hotel()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/cat-collision-hotel.png")
	stage.free()
	print("CAT COLLISION TESTS: ","PASS" if failures == 0 else "FAIL"," (",failures," failures)")
	quit(1 if failures else 0)
