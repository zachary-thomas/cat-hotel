extends SceneTree

const Layout = preload("res://scripts/core/furniture_layout.gd")
const Catalog = preload("res://scripts/core/furniture_catalog.gd")
const F = preload("res://tests/fixtures/build_mode_fixtures.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	test_transforms_and_footprints()
	test_collision_bounds_and_caps()
	test_access_and_routes()
	test_canonical_door_bridge()
	test_templates()
	quit(1 if failures else 0)

func test_transforms_and_footprints() -> void:
	check(Layout.dimensions("regular") == Vector2i(8,6) and Layout.dimensions("suite") == Vector2i(8,10), "Interior dimensions follow the specification")
	var tunnel := F.placed("tunnel", "f1", 2, 1, 1)
	check(Layout.footprint(tunnel) == [Vector2i(3,1),Vector2i(3,2),Vector2i(3,3),Vector2i(2,1),Vector2i(2,2),Vector2i(2,3)], "A non-square footprint rotates clockwise around its origin")
	for kind in ["regular", "suite"]:
		for rotation in range(4):
			var room: Dictionary = F.regular(rotation) if kind == "regular" else F.suite(rotation)
			for local in [Vector2(0,0), Vector2(3.5,2.5), Vector2(8, Layout.dimensions(kind).y)]:
				check(Layout.world_to_local(room, Layout.local_to_world(room,local)).is_equal_approx(local), "Local/world transforms are inverse for %s rotation %d" % [kind,rotation])

func test_collision_bounds_and_caps() -> void:
	var room := F.regular()
	check(Layout.validate(room, [F.placed("mat","f1",0,0),F.placed("rug","f2",0,0)]).ok, "A rug can lie below a floor object")
	check(Layout.validate(room, [F.placed("rug","f1",0,0),F.placed("rug","f2",0,0)]).code == "overlap", "Rugs cannot overlap rugs")
	check(Layout.validate(room, [F.placed("box","f1",0,0),F.placed("plant","f2",1,1)]).code == "overlap", "Floor objects cannot overlap")
	check(Layout.validate(room, [F.placed("tunnel","f1",7,0,1)], false).code == "outside", "Rotated footprints stay within room bounds")
	var many: Array = []
	for index in range(17): many.append(F.placed("plant","f%d" % index,index % 6,int(index / 6)))
	check(Layout.validate(room,many,false).code == "room_full", "Regular rooms enforce the sixteen-instance cap")

func test_access_and_routes() -> void:
	var room := F.regular()
	var items := [F.placed("mat","f1",0,0), F.placed("box","f2",4,0)]
	var valid: Dictionary = Layout.validate(room,items)
	check(valid.ok and valid.paths.has("f1") and valid.paths.has("f2"), "Every interactive object gets a reachable approach path")
	items.append(F.placed("tower","f3",6,2))
	check(Layout.validate(room,items).code == "door_blocked", "The two by two door apron remains clear")
	check(Layout.validate(room,[F.placed("box","f1",0,0)]).code == "missing_bed", "Apply requires a sleep object")
	var blocked := [F.placed("mat","bed",0,0),F.placed("rug","r",0,0),F.placed("table","wall",3,0),F.placed("table","wall2",3,3,1)]
	check(not Layout.validate(room,blocked).ok, "Blocking all approaches to an existing bed is rejected")
	var route: Array[Vector3] = Layout.route_to(room,[F.placed("mat","bed",0,0)],"bed")
	var expected_target := Layout.local_to_world(room,Vector2(1.5,2.0)); expected_target.y += 0.64
	check(route.size() >= 2 and route.back().is_equal_approx(expected_target), "Object route ends at its rotated animation target")
	var housekeeping := Layout.housekeeping_world(room,[F.placed("mat","bed",0,0)])
	check(housekeeping != Vector3.ZERO and Layout.world_to_local(room,housekeeping).x >= 0.0, "Housekeeping exposes a reachable world point")
	var moved := [F.placed("mat","bed",0,2)]
	check(Layout.validate(room,moved).ok and Layout.route_to(room,moved,"bed")[-1] != route[-1], "Moving a bed moves its actual use target")

func test_canonical_door_bridge() -> void:
	for kind in ["regular","suite"]:
		for rotation in range(4):
			var room := F.regular(rotation) if kind == "regular" else F.suite(rotation)
			var bridge: Dictionary = Layout.entrance_transition(room)
			var local_inside := Layout.world_to_local(room,bridge.inside)
			check(local_inside.is_equal_approx(Vector2(7.5,5.0 if kind == "suite" else 3.0)), "Every shell rotation uses the centered canonical inside handoff")
			check(bridge.outside.distance_to(bridge.inside) <= 0.56 and bridge.outside.distance_to(bridge.inside) >= 0.27, "Door bridge crosses one wall edge without a diagonal shortcut")
			var route := Layout.route_to(room,[F.placed("mat","bed",0,0)],"bed")
			check(route[0].is_equal_approx(bridge.inside), "Every interior route begins at the shared door handoff")

func test_templates() -> void:
	for kind in ["regular","suite"]:
		var starter: Array = Layout.template(kind)
		check(starter.size() == (6 if kind == "suite" else 4), "Starter template contains its exact furniture and fixtures")
		for rotation in range(4):
			var room := F.regular(rotation) if kind == "regular" else F.suite(rotation)
			var records: Array = []
			for index in starter.size():
				var value: Dictionary = starter[index].duplicate(); value.uid = "t%d" % index; value.hotel=0; value.room=0; records.append(value)
			check(Layout.validate(room,records).ok, "%s starter validates at shell rotation %d" % [kind,rotation])
	var legacy := Layout.template("regular",["heated","tower","rug"])
	var ids: Array = legacy.map(func(value): return value.item)
	check(legacy.size() == 4 and ids.has("heated") and ids.has("tower") and ids.has("rug") and ids.has("room_nightstand"), "Migration preserves the actual legacy trio without adding starter objects")
	for bed in ["mat","sun_cushion","cave","heated","blanket"]:
		for activity in ["box","perch","tunnel","tower","table"]:
			for decor in ["plant","rug","scratch","lamp","flowers"]:
				for kind in ["regular","suite"]:
					var values: Array = Layout.template(kind,[bed,activity,decor])
					check(values.size() == (6 if kind == "suite" else 4), "Every legacy trio fits in %s" % kind)
					var records: Array = []
					for index in values.size():
						var value: Dictionary = values[index].duplicate(); value.uid="l%d" % index; value.hotel=0; value.room=0; records.append(value)
					for rotation in range(4):
						var room := F.regular(rotation) if kind == "regular" else F.suite(rotation)
						check(Layout.validate(room,records).ok, "Generated legacy template validates at every shell rotation")
