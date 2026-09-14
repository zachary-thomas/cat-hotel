extends Node3D
## Cat-only cast. Waypoint routines keep guests out of furniture and staff in aisles.
const SURFACE = preload("res://assets/shaders/voxel_surface.gdshader")
const SHADOW = preload("res://assets/shaders/contact_shadow.gdshader")
const Navigation = preload("res://scripts/world/cat_navigation.gd")
var motion_enabled: bool = true
var phase: float = 0.0
var body: Node3D
var head: Node3D
var tail: Node3D
var eyes: Array = []
var legs: Array = []
var routine: Array = []
var movement_guard: Callable = Callable()
var waypoint: int = 0
var wait_left: float = 0.0
var action: String = "rest"
var moving: bool = false
var walking: bool = false
var thought: Label3D
var coat: Color
var ears: Array = []
var mouth: MeshInstance3D
var props: Dictionary = {}
var reaction: String = ""
var reaction_time: float = 0.0
var reaction_duration: float = 4.0
var is_staff: bool = false
var stroke_direction: Vector2 = Vector2.ZERO
static var cube: BoxMesh
static var materials: Dictionary = {}

func build(color: Color, staff: bool = false) -> void:
	add_to_group(Navigation.GROUP)
	coat = color
	is_staff = staff
	if cube == null:
		cube = BoxMesh.new()
		cube.size = Vector3.ONE
	body = Node3D.new()
	add_child(body)
	part(body, Vector3(0, 0.35, 0), Vector3(0.48, 0.42, 0.7), coat)
	head = Node3D.new()
	body.add_child(head)
	head.position = Vector3(0, 0.63, 0.28)
	part(head, Vector3.ZERO, Vector3(0.60, 0.48, 0.46), coat)
	for x in [-0.21, 0.21]:
		ears.append(part(head, Vector3(x, 0.30, 0), Vector3(0.18, 0.23, 0.20), coat))
		part(head, Vector3(x, 0.31, 0.108), Vector3(0.085, 0.13, 0.025), Color("d99c95"))
		var eye = part(head, Vector3(x * 0.72, 0.035, 0.239), Vector3(0.068, 0.09, 0.028), Color("28352d"))
		eyes.append(eye)
		part(head, Vector3(x * 0.72 - 0.01, 0.055, 0.258), Vector3(0.018, 0.025, 0.012), Color("fff9e9"))
		part(head, Vector3(x, -0.115, 0.247), Vector3(0.075, 0.04, 0.03), Color("d7a18b"))
	part(head, Vector3(0, -0.11, 0.246), Vector3(0.28, 0.15, 0.07), Color("fff0da"))
	part(head, Vector3(0, -0.065, 0.30), Vector3(0.08, 0.055, 0.03), Color("ad7973"))
	mouth = part(head, Vector3(0, -0.13, 0.29), Vector3(0.02, 0.055, 0.02), Color("655c48"))
	for x in [-0.16, 0.16]:
		for z in [-0.23, 0.25]:
			var leg = Node3D.new()
			body.add_child(leg)
			leg.position = Vector3(x, 0.18, z)
			part(leg, Vector3(0, -0.055, 0), Vector3(0.15, 0.23, 0.19), Color("f4ead5"))
			legs.append(leg)
	tail = Node3D.new()
	body.add_child(tail)
	tail.position = Vector3(0, 0.38, -0.36)
	part(tail, Vector3(0, 0.19, -0.14), Vector3(0.13, 0.40, 0.13), coat)
	part(tail, Vector3(0, 0.37, -0.07), Vector3(0.13, 0.13, 0.25), Color("f4ead5"))
	if staff:
		part(body, Vector3(0, 0.40, 0.20), Vector3(0.50, 0.26, 0.09), Color("426f56"))
		part(body, Vector3(0, 0.51, 0.37), Vector3(0.14, 0.07, 0.05), Color("d7ac50"))
		part(head, Vector3(0, 0.25, 0), Vector3(0.36, 0.10, 0.36), Color("426f56"))
		part(head, Vector3(0, 0.24, 0.22), Vector3(0.40, 0.065, 0.15), Color("31503a"))
		if int(get_meta("cat_index", 0)) == 2:
			for i in range(2):
				part(body, Vector3(0, 0.64 + i * 0.09, -0.15), Vector3(0.57, 0.08, 0.32), Color("f5e9ca") if i == 0 else Color("a4b883"))
	else:
		for z in [-0.21, 0.02]:
			part(body, Vector3(0, 0.57, z), Vector3(0.485, 0.055, 0.075), coat.darkened(0.19))
		for x in [-0.11, 0.11]:
			part(head, Vector3(x, 0.22, 0.12), Vector3(0.055, 0.045, 0.23), coat.darkened(0.19))
	var shadow = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(1.25, 1.35)
	shadow.mesh = plane
	var mat = ShaderMaterial.new()
	mat.shader = SHADOW
	shadow.material_override = mat
	shadow.position.y = 0.015
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	thought = Label3D.new()
	thought.font = preload("res://assets/fonts/Fredoka.ttf")
	thought.font_size = 40
	thought.pixel_size = 0.006
	thought.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	thought.modulate = Color("fff8de")
	thought.outline_modulate = Color("607959")
	thought.outline_size = 7
	thought.position.y = 1.45
	add_child(thought)
	phase = float(get_meta("cat_index", 0)) * 1.71
	_build_props()

func _build_props() -> void:
	for id in ["box","blanket","toy","suitcase","hat","hammer","broom","shears","towels","spoon","key"]:
		var prop = Node3D.new()
		prop.name = id.capitalize()
		body.add_child(prop)
		props[id] = prop
		prop.visible = false
	for side in [-1,1]:
		part(props.box, Vector3(side * 0.39,0.24,0),Vector3(0.05,0.43,0.90),Color("b58b59"))
		part(props.box, Vector3(0,0.24,side * 0.43),Vector3(0.8,0.43,0.05),Color("c8a46d"))
	part(props.blanket,Vector3(0,0.64,0),Vector3(0.70,0.15,0.96),Color("adbac5"))
	part(props.toy,Vector3(0,0.10,0.95),Vector3(0.20,0.18,0.20),Color("d7a078"))
	part(props.suitcase,Vector3(0.43,0.20,-0.15),Vector3(0.25,0.4,0.42),Color("9a6954"))
	part(props.suitcase,Vector3(0.43,0.44,-0.15),Vector3(0.13,0.08,0.06),Color("d5b77d"))
	part(props.hat,Vector3(0,1.20,0.26),Vector3(0.65,0.10,0.5),Color("e1ba55"))
	part(props.hat,Vector3(0,1.26,0.24),Vector3(0.43,0.18,0.34),Color("f0cd73"))
	part(props.hammer,Vector3(0.3,0.48,0.64),Vector3(0.08,0.08,0.55),Color("ac8054"))
	part(props.hammer,Vector3(0.3,0.48,0.91),Vector3(0.36,0.18,0.16),Color("667578"))
	part(props.broom,Vector3(0.34,0.65,0.55),Vector3(0.065,1.0,0.065),Color("bc946b"))
	part(props.broom,Vector3(0.34,0.13,0.55),Vector3(0.50,0.22,0.16),Color("e3c270"))
	for side in [-1,1]:
		part(props.shears,Vector3(0.3+side*0.12,0.5,0.7),Vector3(0.07,0.06,0.6),Color("adc3c3"))
		part(props.shears,Vector3(0.3+side*0.12,0.5,0.38),Vector3(0.12,0.10,0.18),Color("d98581"))
	for i in range(3):
		part(props.towels,Vector3(0,0.65+i*0.10,-0.14),Vector3(0.60,0.09,0.36),Color("eedfc3") if i%2 == 0 else Color("9db4aa"))
	part(props.spoon,Vector3(0.24,0.33,0.58),Vector3(0.06,0.05,0.45),Color("ac8054"))
	part(props.spoon,Vector3(0.24,0.32,0.83),Vector3(0.17,0.05,0.15),Color("ac8054"))
	part(props.key,Vector3(0,0.49,0.64),Vector3(0.05,0.04,0.32),Color("d8b558"))
	part(props.key,Vector3(0,0.49,0.83),Vector3(0.14,0.04,0.09),Color("d8b558"))

func react(kind: String, seconds: float = 4.0) -> void:
	reaction = kind
	reaction_time = 0.0
	reaction_duration = maxf(seconds, 0.5)
	thought.text = {"purr":"♥ purrr", "brush":"♥", "friendship":"♥  ♥", "head_bump":"♥", "celebrate":"Hooray!", "inspect":"Taking notes…", "construction":"Hard at work", "arrival":"Hello!", "departure":"See you soon!"}.get(kind, "")

func stroke(direction: Vector2) -> void:
	stroke_direction = direction.limit_length(1.0)

func part(parent: Node3D, pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var key: String = color.to_html()
	if not materials.has(key):
		var material = ShaderMaterial.new()
		material.shader = SURFACE
		material.set_shader_parameter("tint", color)
		material.set_shader_parameter("grain", 0.0)
		materials[key] = material
	var item = MeshInstance3D.new()
	item.mesh = cube
	item.material_override = materials[key]
	item.position = pos
	item.scale = dimensions
	parent.add_child(item)
	return item

func set_routine(points: Array) -> void:
	routine = points
	waypoint = 0
	place_at(routine[0].position)
	_arrive()

func place_at(point: Vector3) -> void:
	Navigation.place(self,point)

func move_safely(target: Vector3, distance: float) -> bool:
	var guard: Callable = routine[waypoint].get("guard",movement_guard) if not routine.is_empty() else movement_guard
	return Navigation.move(self,target,distance,guard)

func _arrive() -> void:
	moving = false
	walking = false
	action = routine[waypoint].get("action", "rest")
	wait_left = float(routine[waypoint].get("wait", 4.0))
	rotation.y = float(routine[waypoint].get("face", -0.3))
	thought.text = "z z z" if action == "sleep" else ("purrr" if action == "play" else "")

func _process(delta: float) -> void:
	if body == null:
		return
	if reaction != "":
		reaction_time += delta
		if reaction_time >= reaction_duration:
			reaction = ""
			thought.text = "z z z" if action == "sleep" else ""
	if not motion_enabled:
		return
	phase += delta
	walking = moving and reaction == ""
	if reaction == "" and not routine.is_empty():
		if wait_left > 0:
			wait_left -= delta
		elif routine.size() > 1:
			if not moving:
				waypoint = (waypoint + 1) % routine.size()
				moving = true
				action = "walk"
				thought.text = ""
			var target: Vector3 = routine[waypoint].position
			var previous: Vector3 = position
			walking = move_safely(target,delta * 0.68)
			var direction: Vector3 = position - previous
			if walking:
				rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1, delta * 7))
			# Courtyard idles can use the free spot just short of their goal.
			# Beds, furniture and route waypoints still require exact arrival.
			var nearby: bool = not walking and routine[waypoint].get("allow_nearby",false) and position.distance_to(target) < 0.75
			if position.distance_to(target) < 0.025 or nearby:
				_arrive()
	body.scale = Vector3(1, 1, 1)
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	mouth.scale = Vector3(0.02,0.055,0.02)
	for prop in props.values():
		prop.visible = false
		prop.position = Vector3.ZERO
		prop.rotation = Vector3.ZERO
	for leg in legs:
		leg.rotation.z = 0.0
	for i in range(legs.size()):
		legs[i].rotation.x = sin(phase * 9 + (i % 3) * PI) * 0.30 if walking else 0.0
	tail.rotation.z = sin(phase * 1.8) * 0.17
	match action:
		"walk": body.position.y = absf(sin(phase * 9)) * 0.04 if walking else 0.0
		"sleep":
			body.scale.y = 0.66 + sin(phase * 1.6) * 0.02
			head.rotation.x = -0.12
		"eat", "work": head.rotation.x = 0.12 + sin(phase * 3.5) * 0.12
		"play":
			body.position.y = maxf(0, sin(phase * 2)) * 0.17
			head.rotation.z = sin(phase * 1.5) * 0.15
		_:
			body.scale.y = 1 + sin(phase * 1.8) * 0.015
			head.rotation.z = sin(phase * 0.9) * 0.05
	for eye in eyes:
		eye.scale.y = 0.012 if action == "sleep" or fmod(phase, 5.3) < 0.12 else 0.09
	for i in range(ears.size()):
		ears[i].rotation.z = sin(phase * 0.6 + i) * 0.09
	var pose: String = reaction
	var pose_time: float = reaction_time
	if pose == "" and not moving:
		if is_staff:
			pose = ["checkin","cook","towels"][int(get_meta("cat_index",0)) % 3]
		elif action == "rest":
			var idle_poses = ["rest","groom","rest","yawn","rest","stretch","rest","loaf"]
			pose = idle_poses[posmod(int(phase / 6.0),idle_poses.size())]
		elif action == "play":
			pose = "pounce"
		elif action in ["arrival","departure","settle","sniff","greet"]:
			pose = action
		pose_time = fmod(phase,4.0)
	_animate_pose(pose,pose_time)
	thought.position.y = 1.45 + sin(phase * 1.8) * 0.06

func _close_eyes() -> void:
	for eye in eyes:
		eye.scale.y = 0.012

func _animate_pose(pose: String, time: float) -> void:
	var ease: float = sin(clampf(time / maxf(0.5,reaction_duration),0,1) * PI)
	match pose:
		"purr", "brush", "head_bump":
			_close_eyes()
			head.rotation.z = sin(time * 2.0) * 0.14 + stroke_direction.x * 0.10
			head.rotation.x = -0.12 + stroke_direction.y * 0.10
			body.scale.y = 0.91 + sin(phase * 25) * 0.007
			for i in [1,3]:
				legs[i].rotation.x = sin(time * 6 + i * PI * 0.5) * 0.23
			tail.rotation.z = sin(time) * 0.38
			if pose == "head_bump":
				body.position.z = sin(time * 2) * 0.12
			elif pose=="purr":
				match int(get_meta("cat_index",0)) % 4:
					0: body.scale.y += ease * 0.08
					1: head.rotation.y = sin(time) * 0.13
					2: body.rotation.z = ease * 0.28
					3: body.scale.y -= ease * 0.10
		"pounce", "missed_jump":
			props.toy.visible = true
			var t: float = fmod(time,4.0)
			if t < 1.3:
				body.scale.y = 0.75
				body.rotation.y = sin(t * 22) * 0.07
			elif t < 2.3:
				var jump: float = sin((t-1.3)*PI)
				body.position.y = jump * (0.30 if pose == "missed_jump" else 0.6)
				body.position.z = jump * 0.30
				legs[0].rotation.x = -jump * 0.6
				legs[2].rotation.x = -jump * 0.6
			else:
				head.rotation.x = 0.25
				props.toy.position.z = -0.38
		"chase", "zoomies":
			props.toy.visible = pose == "chase"
			props.toy.position.x = sin(time * 3) * 0.4
			body.position.x = sin(time * 3 - 0.5) * 0.34
			body.rotation.y = cos(time * 3) * 0.4
			body.position.y = absf(sin(time * 12)) * 0.06
			for i in range(4):
				legs[i].rotation.x = sin(time * 15 + i * PI * 0.7) * 0.5
		"groom":
			legs[1].rotation.x = -1.5 + sin(time * 5) * 0.2
			head.rotation.x = 0.25
			head.rotation.z = -0.18
		"yawn":
			_close_eyes()
			mouth.scale.y = 0.055 + absf(sin(time * 0.8)) * 0.13
			mouth.scale.x = 0.08
			head.rotation.x = -0.23
		"stretch":
			body.scale.z = 1.0 + absf(sin(time)) * 0.15
			head.rotation.x = 0.25
			legs[1].rotation.x = -0.7
			legs[3].rotation.x = -0.7
		"settle":
			if time < 1.4:
				body.rotation.y = time / 1.4 * TAU
			elif time < 2.8:
				legs[1].rotation.x = sin(time * 8) * 0.3
				legs[3].rotation.x = -sin(time * 8) * 0.3
			else:
				body.scale.y = 0.66
				_close_eyes()
		"loaf", "shared_nap":
			body.scale.y = 0.68
			_close_eyes()
			tail.rotation.z = 0.7
		"box":
			props.box.visible = true
			body.scale.y = 0.72
			head.rotation.z = sin(time) * 0.16
		"blanket":
			props.blanket.visible = true
			body.scale.y = 0.72
			body.position.z = -ease * 0.16
			_close_eyes()
		"sniff":
			head.rotation.x = 0.24 + sin(time * 8) * 0.06
			legs[1].rotation.x = -0.5 * absf(sin(time * 2))
		"friendship":
			if time < 2:
				body.position.z = sin(time * PI / 2) * 0.15
				head.rotation.x = -0.06
			elif time < 4:
				legs[1].rotation.x = -0.9
				head.rotation.z = sin(time * 3) * 0.10
			else:
				body.scale.y = 0.68
				_close_eyes()
		"arrival", "departure":
			props.suitcase.visible = true
			props.suitcase.rotation.z = sin(time * 6) * 0.05
			legs[1].rotation.z = sin(time * 5) * 0.4
			head.rotation.x = sin(time * 2) * 0.15
		"greet", "checkin":
			props.key.visible = is_staff
			head.rotation.x = maxf(0,sin(time * 2)) * 0.3
			legs[1].rotation.x = -0.6 * absf(sin(time * 2))
		"cook":
			props.spoon.visible = true
			props.spoon.rotation.y = sin(time * 4) * 0.45
			legs[1].rotation.x = sin(time * 4) * 0.3
			head.rotation.x = 0.2
		"towels":
			props.towels.visible = true
			props.towels.rotation.z = sin(time * 2) * 0.05
			head.rotation.z = sin(time * 1.3) * 0.07
		"sweep":
			props.broom.visible = true
			props.broom.rotation.z = sin(time*5)*0.25
			legs[1].rotation.x = sin(time*5)*0.3
			head.rotation.x = 0.18
		"trim":
			props.shears.visible = true
			props.shears.rotation.y = sin(time*6)*0.25
			legs[1].rotation.x = sin(time*6)*0.35
		"construction":
			props.hat.visible = true
			props.hammer.visible = true
			props.hammer.rotation.x = -absf(sin(time * 4.5)) * 0.65
			legs[1].rotation.x = sin(time * 9) * 0.55
			body.position.y = absf(sin(time * 4)) * 0.04
		"celebrate":
			body.position.y = maxf(0,sin(time * 4)) * 0.28
			legs[1].rotation.z = 0.45
			legs[3].rotation.z = -0.45
		"inspect":
			head.rotation.y = sin(time * 1.5) * 0.4
			legs[1].rotation.x = -0.65

