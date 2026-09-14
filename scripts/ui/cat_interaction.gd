extends SubViewportContainer
signal interacted(kind: String)
const Cat = preload("res://scripts/world/voxel_cat.gd")
const Content = preload("res://scripts/core/game_content.gd")
var cat_index: int = 0
var cat
var viewport: SubViewport
var held: bool = false
var elapsed: float = 0.0
var last_point: Vector2
var enabled_motion: bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(48,220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.size = Vector2i(380,245)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	add_child(viewport)
	var scene = Node3D.new()
	viewport.add_child(scene)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("FFF0DA")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("fff2da")
	environment.environment.ambient_light_energy = 0.65
	scene.add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	light.light_energy = 0.7
	scene.add_child(light)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.85
	camera.position = Vector3(1.5,1.85,4.6)
	scene.add_child(camera)
	camera.look_at(Vector3(0,0.72,0))
	camera.current = true
	cat = Cat.new()
	cat.set_meta("cat_index",cat_index)
	scene.add_child(cat)
	cat.build(Color(Content.COATS[cat_index]))
	# Frame this guest as a sitting companion, with paws in front of the cushion.
	# These local proportions leave the hotel cats and their routines unchanged.
	cat.head.position.y = 0.92
	cat.head.scale = Vector3.ONE * 1.10
	# Lift the cream chest off the body face to avoid coplanar flicker up close.
	cat.body.get_child(1).position.z += 0.02
	for leg in cat.legs:
		if leg.position.z > 0: leg.position.z = 0.43
	cat.motion_enabled = enabled_motion
	cat.action = "sleep"
	# Set the relaxed shape immediately, including when animations are disabled.
	cat.body.scale.y = 0.68
	cat.position.y = 0.32
	_room(scene)
	gui_input.connect(_gesture)

func _room(scene: Node3D) -> void:
	# A tiny sunlit room grounds the live cat; every detail is runtime geometry.
	part(scene, Vector3(0,-0.08,0), Vector3(5,0.12,5), Color("E6CAA0"))
	for x in range(-3,4):
		part(scene, Vector3(x*0.65,-0.012,0), Vector3(0.012,0.012,5), Color("D4B58F"))
	part(scene, Vector3(0,1.1,-1.15), Vector3(5,2.4,0.08), Color("FFF3DD"))
	var cushion := part(scene, Vector3(0,0.13,0), Vector3.ONE, Color("FFCC68"))
	cushion.name = "CozyCushion"
	var pillow := SphereMesh.new()
	pillow.radius = 0.84
	pillow.height = 1.68
	cushion.mesh = pillow
	cushion.scale = Vector3(1,0.23,0.82)
	var seam := part(scene, Vector3(0,0.14,0), Vector3.ONE, Color("EDB34F"))
	var piping := TorusMesh.new()
	piping.inner_radius = 0.81
	piping.outer_radius = 0.84
	seam.mesh = piping
	seam.scale = Vector3(1,0.4,0.82)
	part(scene, Vector3(-1.10,1.22,-1.07), Vector3(0.92,1.42,0.07), Color("C69C6C"))
	part(scene, Vector3(-1.10,1.22,-1.02), Vector3(0.78,1.28,0.04), Color("C9E8D5"))
	part(scene, Vector3(-1.10,1.22,-0.97), Vector3(0.05,1.3,0.05), Color("FFF8E9"))
	part(scene, Vector3(-1.10,1.22,-0.97), Vector3(0.8,0.05,0.05), Color("FFF8E9"))
	part(scene, Vector3(1.1,0.85,-1.04), Vector3(0.56,0.65,0.06), Color("D4AF82"))
	part(scene, Vector3(1.1,0.85,-0.99), Vector3(0.45,0.54,0.04), Color("DCD2F3"))
	part(scene, Vector3(1.1,0.85,-0.95), Vector3(0.20,0.20,0.04), Color("FFCC68"))
	part(scene, Vector3(-1.05,0.20,-0.45), Vector3(0.32,0.4,0.32), Color("D8A279"))
	for i in range(5):
		var leaf := part(scene, Vector3(-1.05 + sin(i*2.0)*0.15,0.50+i*0.09,-0.45), Vector3(0.34,0.13,0.18), Color("70A878") if i%2 else Color("5CC8A1"))
		leaf.rotation.z = sin(i*2.0)*0.55

func part(parent: Node3D, point: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	piece.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	piece.material_override = material
	piece.position = point
	parent.add_child(piece)
	return piece

func _input(event: InputEvent) -> void:
	# Touch releases are not necessarily delivered to the original GUI control.
	if (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed):
		held = false

func play(kind: String, emit_action: bool = true) -> void:
	if cat == null:
		return
	cat.action = "rest"
	cat.react({"pet":"purr","wand":"pounce","yarn":"chase","cushion":"settle","bell":"greet"}.get(kind,kind),4.0)
	if emit_action:
		interacted.emit(kind)

func _gesture(event: InputEvent) -> void:
	if OS.has_feature("mobile") and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		held = event.pressed
		last_point = event.position
		if held:
			elapsed = 0
			play("pet")
		accept_event()
	elif event is InputEventScreenTouch:
		held = event.pressed
		last_point = event.position
		if held:
			elapsed = 0
			play("pet")
		accept_event()
	elif (event is InputEventMouseMotion and held) or event is InputEventScreenDrag:
		if cat != null:
			cat.stroke((event.position-last_point)/20.0)
		last_point = event.position
		accept_event()

func _process(delta: float) -> void:
	if cat != null and cat.reaction == "": cat.action = "sleep"
	if held:
		elapsed += delta
		if elapsed >= 2.5:
			elapsed = 0
			play("pet")

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		held = false
	elif what == NOTIFICATION_MOUSE_EXIT:
		held = false
