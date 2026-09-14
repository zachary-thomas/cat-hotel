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
	custom_minimum_size = Vector2(240,245)
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
	environment.environment.background_color = Color("e2e9d5")
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
	camera.size = 2.0
	camera.position = Vector3(2,1.65,3.6)
	scene.add_child(camera)
	camera.look_at(Vector3(0,0.62,0))
	camera.current = true
	cat = Cat.new()
	cat.set_meta("cat_index",cat_index)
	scene.add_child(cat)
	cat.build(Color(Content.COATS[cat_index]))
	cat.motion_enabled = enabled_motion
	cat.action = "rest"
	gui_input.connect(_gesture)

func play(kind: String, emit_action: bool = true) -> void:
	if cat == null:
		return
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
