extends Node3D
signal zone_selected(index: int)
signal cat_selected(index: int)
signal expansion_selected(index: int)
signal staff_selected(index: int)
signal grounds_selected(action: String, payload: Dictionary)
signal room_selected(index: int)
signal build_tapped(point: Vector2)
const Layout = preload("res://scripts/core/room_layout.gd")
const Garden = preload("res://scripts/core/garden_layout.gd")
const Interior = preload("res://scripts/core/furniture_layout.gd")
const Catalog = preload("res://scripts/core/furniture_catalog.gd")
var room_builder
var build_mode: bool = false
var edited_room: int = -1
var layout_cast_key: String = ""
var neighborhood
var shell
var exterior_view: bool = false
var overview_zoom: float = 48.0
var neighborhood_zoom: float = 110.0
var ui_world_rect := Rect2()
const ISO_RIGHT = Vector3(0.70710678, 0, -0.70710678)
const ISO_UP = Vector3(-0.40824829, 0.81649658, -0.40824829)
const Cat = preload("res://scripts/world/voxel_cat.gd")
const Content = preload("res://scripts/core/game_content.gd")
const SURFACE = preload("res://assets/shaders/voxel_surface.gdshader")
const FOLIAGE = preload("res://assets/shaders/foliage.gdshader")
const SHADOW = preload("res://assets/shaders/contact_shadow.gdshader")
const WATER = preload("res://assets/shaders/water.gdshader")
const DEFAULT_ZOOM = 23.0
const TOTAL_WINGS = 3
var overview: bool = true
var repair_wing: int = -1
var builders: Array = []
var repair_root: Node3D
var camera: Camera3D
var building: Node3D
var cast_root: Node3D
var actors: Array = []
var blocks: Dictionary = {}
var animated_materials: Array = []
var cube: BoxMesh
var zone_centers: Array[Vector3] = [Vector3(-2.6, 0, -2.1), Vector3(2.6, 0, -2.1), Vector3(2.6, 0, 2.1), Vector3(-2.6, 0, 2.1)]
var hotel_index: int = -1
var zone_levels: Array = [1, 0, 0, 0]
var motion_enabled: bool = true
var pointer_start: Vector2
var dragging: bool = false
var gesture_distance: float = 0.0
var touches: Dictionary = {}
var camera_target: Vector3 = Vector3.ZERO
var wood: Color
var accent: Color
var trim: Color
var effect_time: float = 0.0
var wings: int = 0
var evening: bool = false
var environment_settings: Environment
var sun: DirectionalLight3D
var lamps: Array = []
var lamp_glows: Array = []
var light_pools: Array = []
var room_centers: Array[Vector3] = []
var crown_mesh: ArrayMesh
var life_root: Node3D
var life_key: String = ""
var follow_cat: int = -1
var room_cast_keys: Dictionary = {}
var weather_enabled: bool = true
var transient_pairs: Array = []
var event_active: bool = false
var ambient_clock: float = 0.0
var weather_particles: GPUParticles3D

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	cube = BoxMesh.new()
	cube.size = Vector3.ONE
	var environment = WorldEnvironment.new()
	var settings = Environment.new()
	environment_settings = settings
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("e6efdb")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("e6edf0")
	settings.ambient_light_energy = 0.34
	environment.environment = settings
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-49, -28, 0)
	sun.light_color = Color("fff4e6")
	sun.light_energy = 0.43
	sun.shadow_enabled = true
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.3
	sun.directional_shadow_max_distance = 42
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = DEFAULT_ZOOM
	camera.near = 0.5
	camera.far = 600
	add_child(camera)
	camera.current = true
	_update_camera()
	var grade_layer = CanvasLayer.new()
	grade_layer.layer = 0
	add_child(grade_layer)
	var grade = ColorRect.new()
	grade.name = "CozyColorGrade"
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/cozy_grade.gdshader")
	grade.material = mat
	grade_layer.add_child(grade)
	show_hotel(0, [1, 0, 0, 0])
	_setup_weather()
	neighborhood = preload("res://scripts/world/neighborhood.gd").new()
	neighborhood.world = self
	add_child(neighborhood)
	neighborhood.selected.connect(func(action, payload): grounds_selected.emit(action,payload))
	get_viewport().size_changed.connect(_viewport_resized)

func _update_camera() -> void:
	_clamp_camera()
	var distance := maxf(32,camera.size*0.85)
	camera.position = camera_target + Vector3.ONE*distance
	sun.directional_shadow_max_distance=distance*sqrt(3.0)+40.0
	camera.look_at(camera_target)

func navigation_bounds() -> Rect2:
	return Garden.CAMERA_BOUNDS

func contains_hotel(point: Vector3) -> bool:
	return absf(point.x) < 5.95 and point.z > -17.4 and point.z < 4.9

func set_exterior_view(value: bool) -> void:
	exterior_view = value and not build_mode
	if room_builder != null:
		room_builder.visible = not exterior_view
	if shell != null:
		shell.set_outside(exterior_view)

func _projected_bounds(bounds: Rect2 = Rect2(-18,-26,36,38.8)) -> Rect2:
	var projected = Rect2()
	var first: bool = true
	for x in [bounds.position.x, bounds.end.x]:
		for z in [bounds.position.y, bounds.end.y]:
			var point = Vector3(x, 0, z)
			var p = Vector2(point.dot(ISO_RIGHT),point.dot(ISO_UP))
			if first:
				projected = Rect2(p,Vector2.ZERO)
				first = false
			else:
				projected = projected.expand(p)
	return projected

func _measure_overview() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var bounds = _projected_bounds()
	var region := available_world_rect()
	overview_zoom = maxf(bounds.size.x * viewport_size.x / (region.size.x * 0.92),(bounds.size.y+3.0)*viewport_size.x/(region.size.y * 0.88))
	# Keep Fit all useful for the property; allow another step out to explore its district.
	neighborhood_zoom = maxf(overview_zoom,110.0)

func available_world_rect() -> Rect2:
	return ui_world_rect if ui_world_rect.has_area() else get_viewport().get_visible_rect()

func set_ui_world_rect(rect: Rect2) -> void:
	if rect == ui_world_rect: return
	ui_world_rect = rect
	if camera != null: _viewport_resized()

func _center_projected(bounds: Rect2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var offset := (available_world_rect().get_center() - viewport_size * 0.5) * camera.size / viewport_size.x
	var center := bounds.get_center() + Vector2(-offset.x, offset.y)
	camera_target = Vector3(center.x / ISO_RIGHT.x + center.y / ISO_UP.x, 0, -center.x / ISO_RIGHT.x + center.y / ISO_UP.x) * 0.5
	_update_camera()

func visible_mesh_points(node: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not node.is_visible_in_tree(): return points
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		var bounds: AABB = node.mesh.get_aabb() if node is MeshInstance3D else AABB()
		if node is MultiMeshInstance3D and node.multimesh != null:
			# Calculate CPU bounds too: headless rendering does not populate the batch AABB.
			for index in range(node.multimesh.instance_count):
				var instance_bounds: AABB = node.multimesh.get_instance_transform(index) * node.multimesh.mesh.get_aabb()
				bounds = instance_bounds if index == 0 else bounds.merge(instance_bounds)
		for corner in range(8): points.append(node.global_transform * bounds.get_endpoint(corner))
	for child in node.get_children():
		if child is Node3D: points.append_array(visible_mesh_points(child))
	return points

func active_hotel_bounds() -> Rect2:
	var points: Array[Vector3] = []
	if exterior_view and shell != null:
		points.append_array(visible_mesh_points(shell.exterior))
	elif room_builder != null:
		for room in room_builder.room_nodes: points.append_array(visible_mesh_points(room))
	# Reception anchors the active rooms; unused public floor and future wings do not shrink guests.
	points.append_array([Vector3(-1.2,0,0.4),Vector3(1.2,1.6,2.0)])
	var bounds := Rect2(Vector2(points[0].dot(ISO_RIGHT),points[0].dot(ISO_UP)),Vector2.ZERO)
	for point in points: bounds = bounds.expand(Vector2(point.dot(ISO_RIGHT),point.dot(ISO_UP)))
	return bounds

func _clamp_camera() -> void:
	var bounds = navigation_bounds()
	# Bounds constrain the visible area's center; scenic land/water extends beyond it.
	var viewport_size := get_viewport().get_visible_rect().size
	var offset := (available_world_rect().get_center()-viewport_size*0.5)*camera.size/maxf(1,viewport_size.x)
	var shift := Vector2(offset.x/ISO_RIGHT.x-offset.y/ISO_UP.x,-offset.x/ISO_RIGHT.x-offset.y/ISO_UP.x)*0.5
	var center := Vector2(camera_target.x,camera_target.z)+shift
	center = center.clamp(bounds.position,bounds.end)
	camera_target.x = center.x-shift.x
	camera_target.z = center.y-shift.y
	camera_target.y = 0

func set_zoom(value: float) -> void:
	if not is_finite(value):
		return
	camera.size = clampf(value,8.0,neighborhood_zoom)
	_update_camera()

func reset_camera() -> void:
	follow_cat = -1
	overview = true
	_measure_overview()
	camera.size = overview_zoom
	_center_projected(_projected_bounds())

func focus_hotel() -> void:
	follow_cat = -1
	overview = false
	_measure_overview()
	var bounds := active_hotel_bounds()
	var viewport_size := get_viewport().get_visible_rect().size
	var region := available_world_rect()
	var width_fit := bounds.size.x * viewport_size.x / (region.size.x * 0.92)
	var height_fit := bounds.size.y * viewport_size.x / (region.size.y * 0.88)
	camera.size = clampf(maxf(width_fit,height_fit),8.0,overview_zoom)
	_center_projected(bounds)

func _viewport_resized() -> void:
	if overview:
		reset_camera()
	else:
		_measure_overview()
		set_zoom(camera.size)

func focus_zone(index: int) -> void:
	if index >= 0 and index < 4:
		overview = false
		camera_target = zone_centers[index]
		camera.size = 14.0
		_update_camera()

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	for actor in actors:
		actor.motion_enabled = enabled
	for mat in animated_materials:
		mat.set_shader_parameter("motion", 1.0 if enabled else 0.0)

func box(pos: Vector3, dimensions: Vector3, color: Color, leafy: bool = false) -> void:
	var key: String = color.to_html() + ("~" if leafy else "")
	if not blocks.has(key):
		blocks[key] = []
	blocks[key].append(Transform3D(Basis.from_scale(dimensions), pos))

func _flush() -> void:
	for key in blocks:
		var batch = MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = cube
		batch.instance_count = blocks[key].size()
		for i in range(batch.instance_count):
			batch.set_instance_transform(i, blocks[key][i])
		var mat = ShaderMaterial.new()
		mat.shader = FOLIAGE if key.ends_with("~") else (preload("res://assets/shaders/lantern_glass.gdshader") if key.ends_with("!") else SURFACE)
		mat.set_shader_parameter("tint", Color(key.trim_suffix("~").trim_suffix("!")))
		if key.ends_with("~"):
			animated_materials.append(mat)
		var instance = MultiMeshInstance3D.new()
		instance.multimesh = batch
		instance.material_override = mat
		building.add_child(instance)
	blocks.clear()

func show_hotel(index: int, levels: Array, built_wings: int = 0) -> void:
	if camera == null:
		return
	var changed_hotel: bool = hotel_index != index
	var footprint_changed: bool = wings != built_wings
	wings = clampi(built_wings, 0, 3)
	hotel_index = index
	zone_levels = levels.duplicate()
	if building != null:
		remove_child(building)
		building.queue_free()
	animated_materials.clear()
	lamps.clear()
	lamp_glows.clear()
	light_pools.clear()
	room_centers.clear()
	layout_cast_key = ""
	room_cast_keys.clear()
	building = Node3D.new()
	building.name = "FurnishedHotel"
	add_child(building)
	accent = [Color("5cc8a1"),Color("8bb9bb"),Color("bd895e"),Color("aec4d2")][index]
	trim = [Color("4b7354"),Color("437982"),Color("665d3f"),Color("627886")][index]
	wood = [Color("c39a66"),Color("d6b78b"),Color("96734e"),Color("bba083")][index]
	crown_mesh = preload("res://scripts/world/tree_canopy.gd").create([trim, accent, Color("aabc78")])
	_garden(index)
	box(Vector3(0, -0.16, 0), Vector3(11.8, 0.5, 9.6), Color("a68154"))
	# Staggered oak planks, with fine shader grain and highlighted block edges.
	for z in range(-12, 13):
		for x in range(-4, 4):
			var px: float = x * 1.42 + (0.30 if z % 2 == 0 else 0.65)
			box(Vector3(px, 0.10, z * 0.365), Vector3(1.40, 0.13, 0.35), wood.lightened(float(posmod(x * 7 + z * 3, 5)) * 0.018))
	_wall(Vector3(-5.7, 1.30, -1.9), Vector3(0.22, 2.5, 5.6))
	_wall(Vector3(5.7, 0.55, 0), Vector3(0.22, 0.85, 9.4))
	_wall(Vector3(-5.7, 0.55, 2.9), Vector3(0.22, 0.85, 3.7))
	_wall(Vector3(-3.8, 0.59, 4.7), Vector3(3.6, 0.90, 0.22))
	_wall(Vector3(3.8, 0.59, 4.7), Vector3(3.6, 0.90, 0.22))
	for z in [-3.5, -0.3]:
		box(Vector3(-5.50, 1.60, z), Vector3(0.09, 1.10, 1.5), trim)
		box(Vector3(-5.43, 1.60, z), Vector3(0.04, 0.92, 1.3), Color("dddaa1"))
		box(Vector3(-5.39, 1.60, z), Vector3(0.04, 0.92, 0.06), wood)
		box(Vector3(-5.36, 1.05, z), Vector3(0.30, 0.12, 1.6), wood)
	for segment in [Vector2(-5.7,-4.4),Vector2(-3.4,-2.1),Vector2(-1.1,-0.95)]:
		_wall(Vector3((segment.x+segment.y)/2,0.57,0.05),Vector3(segment.y-segment.x,0.85,0.20))
	_wall(Vector3(3.7, 0.57, 0.05), Vector3(3.9, 0.85, 0.20))
	for x in [-0.92, 1.75]:
		box(Vector3(x, 0.98, 0.05), Vector3(0.25, 1.72, 0.27), wood.darkened(0.12))
		_lantern(Vector3(x, 1.86, 0.05))
	_rug(Vector3(0, 0.19, 0.3), Vector2(1.3, 7.4), accent.darkened(0.05))
	for z in [-2.3, 0.4, 3.0]:
		_paw(Vector3(0, 0.22, z), 0.75, Color("dbd9a6"))
	for i in range(4):
		if i == 0:
			_public_lounge()
		else:
			_zone(i, int(levels[i]))
	# Entrance arch, open gates and welcome mat.
	_rug(Vector3(0, -0.025, 5.25), Vector2(1.8, 0.95), trim)
	_paw(Vector3(0, 0.0, 5.25), 0.72, Color("c7ca92"))
	for x in [-1.27, 1.27]:
		box(Vector3(x, 0.65, 4.80), Vector3(0.22, 1.6, 0.22), wood.darkened(0.15))
		_lantern(Vector3(x, 1.55, 4.8))
		box(Vector3(x, 0.48, 5.18), Vector3(0.15, 0.92, 0.82), trim)
	_flush()
	if changed_hotel or cast_root == null:
		if cast_root != null:
			remove_child(cast_root)
			cast_root.queue_free()
		actors.clear()
		cast_root = Node3D.new()
		cast_root.name = "CatRoutines"
		add_child(cast_root)
		_spawn_cast()
	_sync_service_cats()
	if shell == null:
		shell = preload("res://scripts/world/hotel_shell.gd").new()
		shell.world = self
		add_child(shell)
	shell.rebuild()
	set_motion_enabled(motion_enabled)
	set_evening(evening)
	if changed_hotel or footprint_changed:
		reset_camera()

func _wall(pos: Vector3, dimensions: Vector3) -> void:
	box(pos, dimensions, Color("fff8e9"))
	box(pos + Vector3(0, dimensions.y * 0.5 + 0.04, 0), Vector3(dimensions.x + 0.08, 0.16, dimensions.z + 0.08), wood)
	box(Vector3(pos.x, 0.36, pos.z), Vector3(dimensions.x + 0.035, 0.32, dimensions.z + 0.035), wood.darkened(0.07))
	box(Vector3(pos.x, 0.56, pos.z), Vector3(dimensions.x + 0.06, 0.065, dimensions.z + 0.06), wood)

func _window(p: Vector3) -> void:
	_light_pool(Vector3(p.x, 0.254, p.z + 1.5), Vector2(1.4, 2.2), true)
	box(p, Vector3(1.48, 1.42, 0.12), wood.darkened(0.1))
	box(p + Vector3(0, 0, 0.08), Vector3(1.22, 1.18, 0.08), Color("bed8c8"))
	for x in [-0.3, 0.3]:
		box(p + Vector3(x, 0, 0.14), Vector3(0.065, 1.2, 0.06), trim)
	box(p + Vector3(0, 0, 0.16), Vector3(1.23, 0.075, 0.07), trim)
	box(p + Vector3(0, -0.71, 0.14), Vector3(1.66, 0.14, 0.45), wood)
	for x in [-0.79, 0.79]:
		box(p + Vector3(x, -0.02, 0.18), Vector3(0.24, 1.4, 0.12), accent)
		box(p + Vector3(x, -0.19, 0.25), Vector3(0.25, 0.09, 0.08), Color("e3c88d"))

func _rug(p: Vector3, dimensions: Vector2, color: Color) -> void:
	box(p, Vector3(dimensions.x, 0.035, dimensions.y), color.darkened(0.16))
	box(p + Vector3(0, 0.021, 0), Vector3(dimensions.x - 0.13, 0.025, dimensions.y - 0.13), color)
	for x in [-1.0, 1.0]:
		box(p + Vector3(x * (dimensions.x * 0.5 - 0.12), 0.038, 0), Vector3(0.026, 0.012, dimensions.y - 0.24), color.lightened(0.3))

func _paw(p: Vector3, s: float, color: Color) -> void:
	box(p + Vector3(0, 0, 0.12 * s), Vector3(0.38, 0.009, 0.30) * s, color)
	for v in [Vector3(-0.27, 0, -0.10), Vector3(-0.10, 0, -0.28), Vector3(0.12, 0, -0.28), Vector3(0.28, 0, -0.10)]:
		box(p + v * s, Vector3(0.15, 0.009, 0.17) * s, color)

func _zone(index: int, level: int) -> void:
	var c: Vector3 = zone_centers[index]
	var tier: int = 0 if level < 4 else (1 if level < 7 else 2)
	_rug(c + Vector3(0, 0.19, 0), Vector2(4.15, 3.20), accent.lightened(0.20) if index != 1 else Color("dacba7"))
	_shadow(c + Vector3(0, 0.225, 0), Vector2(4.5, 3.6), 0.17)
	plant(c + Vector3(-1.87, 0.22, 1.30), 0.42, true)
	plant(c + Vector3(1.85, 0.22, -1.45), 0.46)
	match index:
		0:
			for offset in [-1.25, 1.20]:
				var b: Vector3 = c + Vector3(offset, 0, -0.65)
				_shadow(b + Vector3(0, 0.23, 0), Vector2(2.15, 2.35), 0.25)
				box(b + Vector3(0, 0.39, 0), Vector3(1.77, 0.39, 1.93), wood.darkened(0.2))
				box(b + Vector3(0, 0.66, 0), Vector3(1.68, 0.23, 1.76), Color("f8ead0"))
				box(b + Vector3(0, 0.80, 0.30), Vector3(1.73, 0.12, 1.12), accent if offset < 0 else Color("cc8865"))
				_paw(b + Vector3(0, 0.864, 0.32), 0.72, Color("ede2b7"))
				for px in [-0.42, 0.42]:
					box(b + Vector3(px, 0.86, -0.48), Vector3(0.66, 0.20, 0.45), Color("fff4dd"))
				box(b + Vector3(0, 0.86, -0.94), Vector3(1.88, 1.35, 0.15), wood.darkened(0.08))
				for px in [-0.85, 0.85]:
					box(b + Vector3(px, 0.96, -0.94), Vector3(0.15, 1.58, 0.22), wood)
				box(b + Vector3(0, 0.44, 1.28), Vector3(1.62, 0.42, 0.48), Color("b67f52"))
				if tier > 0:
					box(b + Vector3(0, 0.92, 0.70), Vector3(1.72, 0.13, 0.25), trim)
				if tier == 2:
					for px in [-0.85, 0.85]:
						box(b + Vector3(px, 1.4, -0.94), Vector3(0.12, 2.4, 0.12), wood)
					box(b + Vector3(0, 2.63, -0.35), Vector3(1.95, 0.16, 1.5), accent)
			box(c + Vector3(0, 0.7, -1.60), Vector3(0.55, 1.0, 0.54), wood)
			_lantern(c + Vector3(0, 1.31, -1.60))
		1:
			box(c + Vector3(0, 0.74, -1.13), Vector3(3.7, 1.15, 0.80), accent)
			box(c + Vector3(0, 1.35, -1.13), Vector3(3.9, 0.15, 1.0), Color("f6ead1"))
			for x in [-1.25, 0, 1.25]:
				box(c + Vector3(x, 0.76, -0.71), Vector3(1.08, 0.83, 0.06), trim)
				box(c + Vector3(x, 0.77, -0.67), Vector3(0.92, 0.67, 0.04), accent)
				box(c + Vector3(x, 1.01, -0.62), Vector3(0.18, 0.055, 0.06), Color("d8b563"))
				_bowl(c + Vector3(x, 0.26, 0.45), x == 0)
			box(c + Vector3(-1.1, 1.46, -1.1), Vector3(0.8, 0.09, 0.57), wood)
			for i in range(3):
				box(c + Vector3(-1.3 + i * 0.2, 1.54, -1.1), Vector3(0.15, 0.1, 0.30), Color("d69c52"))
			for i in range(3):
				box(c + Vector3(0.5 + i * 0.34, 1.59, -1.2), Vector3(0.24, 0.32, 0.24), Color("f4ddb0") if i % 2 else trim)
			plant(c + Vector3(1.55, 1.43, -1.15), 0.32, true)
			if tier > 0:
				box(c + Vector3(0, 1.75, -1.15), Vector3(0.68, 0.65, 0.65), trim)
		2:
			for x in [-0.95, 0.70]:
				box(c + Vector3(x, 0.75, -0.8), Vector3(0.24, 1.10, 0.24), Color("bd9862"))
				for y in [0.4, 0.6, 0.8, 1.0]:
					box(c + Vector3(x, y, -0.8), Vector3(0.26, 0.04, 0.26), Color("d8b786"))
				box(c + Vector3(x, 1.39, -0.8), Vector3(1.22, 0.20, 1.15), trim)
				box(c + Vector3(x, 1.52, -0.8), Vector3(1.1, 0.09, 1.02), accent)
			box(c + Vector3(-0.1, 0.50, 0.45), Vector3(1.2, 0.59, 1.1), wood)
			box(c + Vector3(-0.1, 0.48, 1.01), Vector3(0.56, 0.44, 0.035), Color("554e34"))
			box(c + Vector3(-0.1, 0.83, 0.45), Vector3(1.27, 0.12, 1.16), accent)
			for i in range(3):
				box(c + Vector3(1.65, 0.27 + i * 0.19, -1.1 + i * 0.27), Vector3(0.73, 0.19, 0.30), wood)
			box(c + Vector3(0.95, 0.35, 1.0), Vector3(0.23, 0.23, 0.23), Color("d8b560"))
			if tier > 0:
				box(c + Vector3(-0.95, 1.88, -0.8), Vector3(0.18, 0.68, 0.18), wood)
				box(c + Vector3(-0.95, 2.26, -0.8), Vector3(1.30, 0.19, 1.10), trim)
		3:
			box(c + Vector3(0, 0.72, 0.45), Vector3(3.4, 1.10, 0.88), wood.darkened(0.10))
			box(c + Vector3(0, 1.32, 0.45), Vector3(3.65, 0.16, 1.05), wood.lightened(0.08))
			for x in [-1.1, 0, 1.1]:
				box(c + Vector3(x, 0.74, 0.91), Vector3(0.94, 0.76, 0.05), trim)
				box(c + Vector3(x, 0.74, 0.95), Vector3(0.80, 0.63, 0.035), accent)
			box(c + Vector3(0.7, 1.47, 0.58), Vector3(0.33, 0.14, 0.33), Color("d6a443"))
			box(c + Vector3(0.7, 1.58, 0.58), Vector3(0.15, 0.12, 0.15), Color("f3ce73"))
			box(c + Vector3(-0.4, 1.46, 0.52), Vector3(0.65, 0.07, 0.47), Color("faf0d5"))
			plant(c + Vector3(-1.28, 1.42, 0.35), 0.35, true)
			box(c + Vector3(-1.3, 1.2, -1.7), Vector3(1.62, 1.42, 0.12), wood)
			box(c + Vector3(-1.3, 1.2, -1.61), Vector3(1.41, 1.21, 0.05), trim)
			_sign(c + Vector3(-1.3, 1.25, -1.56), "PURRINGTON\nHOTEL", 27)
			_rug(c + Vector3(0, 0.23, 1.48), Vector2(3.20, 0.73), Color("bf8864"))
	if level == 0 and index != 3:
		_sign(c + Vector3(0, 1.68, 0), "OPEN SERVICE", 21, true)
	if level >= 2:
		plant(c + Vector3(1.82, 0.22, 1.24), 0.40, level >= 3)
	if level >= 5:
		_lantern(c + Vector3(-1.75, 0.95, 1.1))
	if level >= 8:
		_paw(c + Vector3(0, 0.237, 1.15), 0.60, Color("e5c773"))

func _bowl(p: Vector3, water: bool = false) -> void:
	box(p, Vector3(0.73, 0.17, 0.68), trim)
	box(p + Vector3(0, 0.11, 0), Vector3(0.60, 0.065, 0.55), Color("e4d7aa"))
	box(p + Vector3(0, 0.15, 0), Vector3(0.44, 0.035, 0.40), Color("80b6bc") if water else Color("946332"))
	if not water:
		for x in [-0.12, 0.12]:
			for z in [-0.12, 0.06]:
				box(p + Vector3(x, 0.19, z), Vector3(0.10, 0.08, 0.10), Color("bc8842"))

func _sign(p: Vector3, text: String, font_size: int, billboard: bool = false) -> void:
	var sign = Label3D.new()
	sign.font = preload("res://assets/fonts/Fredoka.ttf")
	sign.text = text
	sign.font_size = font_size
	sign.pixel_size = 0.007
	sign.position = p
	sign.modulate = Color("fff4cd")
	sign.outline_size = 3 if billboard else 0
	sign.outline_modulate = trim
	if billboard:
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	building.add_child(sign)

func _lantern(p: Vector3, light: bool = false) -> void:
	var glass_key: String = "ffe5a0ff!"
	if not blocks.has(glass_key):
		blocks[glass_key] = []
	blocks[glass_key].append(Transform3D(Basis.from_scale(Vector3(0.34,0.41,0.34)), p))
	for y in [-0.24, 0.24]:
		box(p + Vector3(0, y, 0), Vector3(0.44, 0.09, 0.44), wood.darkened(0.15))
	for x in [-0.19, 0.19]:
		for z in [-0.19, 0.19]:
			box(p + Vector3(x, 0, z), Vector3(0.04, 0.45, 0.04), wood)
	_lamp_glow(p)
	_light_pool(Vector3(p.x, 0.258, p.z), Vector2(2.9, 2.9), false)
	if (light or lamps.size() < 2) and lamps.size() < 8:
		var lamp = OmniLight3D.new()
		lamp.position = p + Vector3(0, 0.25, 0.1)
		lamp.light_color = Color("ffd88e")
		lamp.light_energy = 0.65
		lamp.omni_range = 3.5
		lamps.append(lamp)
		building.add_child(lamp)

func _shadow(p: Vector3, dimensions: Vector2, strength: float) -> void:
	var mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = dimensions
	mesh.mesh = plane
	mesh.position = p
	var mat = ShaderMaterial.new()
	mat.shader = SHADOW
	mat.set_shader_parameter("strength", strength)
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	building.add_child(mesh)

func plant(p: Vector3, h: float, flowers: bool = false) -> void:
	box(p + Vector3(0, h * 0.30, 0), Vector3(h * 0.70, h * 0.6, h * 0.70), Color("af7959"))
	box(p + Vector3(0, h * 0.59, 0), Vector3(h * 0.82, h * 0.13, h * 0.82), Color("c58e67"))
	for v in [Vector3(-0.3, 0.98, 0.0), Vector3(0.3, 1.12, 0.15), Vector3(0, 1.48, -0.1), Vector3(0, 0.94, 0.30)]:
		box(p + v * h, Vector3(h * 0.53, h * 0.47, h * 0.53), trim if v.y < 1.1 else accent, true)
	if flowers:
		for v in [Vector3(-0.24, 1.24, 0), Vector3(0.28, 1.38, 0.16), Vector3(0, 1.76, -0.1)]:
			box(p + v * h, Vector3.ONE * h * 0.22, Color("fff0c7"))
			box(p + v * h + Vector3(0, h * 0.12, 0), Vector3.ONE * h * 0.10, Color("d9ad4d"))

func _garden(index: int) -> void:
	preload("res://scripts/world/neighborhood_backdrop.gd").build(self,index)
	# Scattered low flowering ground cover gives the landscaped island a lived-in edge.
	for i in range(112):
		var x: float = sin(i * 5.7) * 12.2
		var z: float = cos(i * 3.9) * 11.3
		if (absf(x) < 12.5 and z > -5.5 - TOTAL_WINGS * 4.2 and z < 13.0) or absf(x) < 1.8:
			continue
		var p = Vector3(x, -0.28, z)
		var h: float = 0.16 + (i % 4) * 0.05
		box(p + Vector3(0, h, 0), Vector3(0.37, h, 0.30), accent, true)
		box(p + Vector3(0.15, h * 1.3, 0.08), Vector3(0.23, h, 0.23), trim, true)
		if i % 3 != 0:
			box(p + Vector3(0, h * 1.9, 0), Vector3(0.13, 0.09, 0.13), Color("f6e9bd"))
			box(p + Vector3(0, h * 1.9 + 0.05, 0), Vector3(0.055, 0.03, 0.055), Color("d7b258"))
	# Stone paths with irregular tones, hedges and flowering borders.
	for z in range(-8 - TOTAL_WINGS * 7, 12):
		for x in range(-1, 2):
			box(Vector3(x * 0.62 + (0.15 if z % 2 else 0), -0.10, z * 0.64), Vector3(0.57, 0.18, 0.57), Color("d7cbb0").darkened(float(posmod(z + x, 4)) * 0.022))
	for side in [-1, 1]:
		for z in range(-6 - TOTAL_WINGS * 5, 7):
			box(Vector3(side * 6.25, -0.07, z * 0.86), Vector3(0.66, 0.15, 0.72), Color("cfc3a5"))
			plant(Vector3(side * 6.87, -0.18, z * 0.91), 0.46 + (0.1 if z % 3 else 0.0), z % 2 == 0)
	for x in [-5.4, -4.6, -3.8, -3.0, 2.9, 3.7, 4.5, 5.3]:
		plant(Vector3(x, -0.12, 5.75), 0.49, true)
	for p in [Vector3(-32,-0.25,-40),Vector3(32,-0.25,-40),Vector3(-32,-0.25,-17),Vector3(32,-0.25,-17),Vector3(-32,-0.25,4),Vector3(32,-0.25,4),Vector3(-23,-0.25,-42),Vector3(23,-0.25,-42)]:
		_tree(p,index==1)
	box(Vector3(-3.0, 0.10, 6.8), Vector3(2.0, 0.13, 0.70), wood.darkened(0.08))
	box(Vector3(-3.0, 0.47, 7.12), Vector3(2.0, 0.65, 0.14), wood)
	for x in [-3.75, -2.25]:
		box(Vector3(x, -0.10, 6.8), Vector3(0.16, 0.48, 0.6), trim)

func _tree(p: Vector3, palm: bool) -> void:
	_shadow(p + Vector3(0, 0.10, 0), Vector2(3.5, 3.5), 0.20)
	box(p + Vector3(0, 1.25, 0), Vector3(0.40, 2.7, 0.40), wood.darkened(0.2))
	if palm:
		for offset in [Vector3(-1.1, 2.8, 0), Vector3(1.1, 2.8, 0), Vector3(0, 2.6, -1.1), Vector3(0, 2.6, 1.1)]:
			box(p + offset, Vector3(2.0 if offset.x else 0.58, 0.24, 2.0 if offset.z else 0.58), Color("7d9f69"), true)
	else:
		var crown = MeshInstance3D.new()
		crown.name = "SeamlessTreeCrown"
		crown.mesh = crown_mesh
		crown.position = p + Vector3(0, 2.05, 0)
		crown.custom_aabb = crown_mesh.get_aabb().grow(0.12)
		var material = ShaderMaterial.new()
		material.shader = FOLIAGE
		material.set_shader_parameter("tint", Color.WHITE)
		crown.material_override = material
		animated_materials.append(material)
		building.add_child(crown)
func _spawn_cast() -> void:
	_spawn_cat(0, Color("454a40"), true, [{"position": Vector3(-2.5, 0.22, 1.77), "action": "work", "wait": 20.0}])
	_spawn_cat(0, Color("dc9e57"), false, [{"position": Vector3(-3.82, 0.87, -2.55), "action": "sleep", "wait": 30.0}])
	_spawn_cat(2, Color("e3b477"), true, [{"position": Vector3(0, 0.23, 3.6), "action": "rest", "wait": 1.0}, {"position": Vector3(0, 0.23, -1.15), "action": "work", "wait": 3.0}])
	_spawn_cat(2, Color("343e35"), false, [{"position": Vector3(1.02, 0.23, 3.8), "action": "rest", "wait": 2.0}, {"position": Vector3(4.0, 0.23, 3.8), "action": "play", "wait": 5.0}])
	_spawn_cat(1, Color("939c8e"), false, [{"position": Vector3(-3.15, 0.18, 6.65), "action": "rest", "wait": 20.0}])

func _sync_service_cats() -> void:
	var ids: Array = []
	for actor in actors:
		ids.append(actor.get_meta("cat_index"))
	if zone_levels[1] > 0 and not actors.any(func(actor): return actor.is_staff and int(actor.get_meta("cat_index"))==1):
		_spawn_cat(1,Color("d4b17f"),true,[{"position":Vector3(2.0,0.23,-3.4),"action":"work","wait":18.0}])
	if zone_levels[1] > 0 and not ids.has(5):
		_spawn_cat(5, Color("eee5ce"), false, [{"position": Vector3(3.85, 0.24, -1.12), "action": "eat", "face": PI, "wait": 8.0}, {"position": Vector3(4.7, 0.24, -0.8), "action": "rest", "wait": 5.0}])
	if zone_levels[2] > 0 and not ids.has(6):
		_spawn_cat(6, Color("656d66"), false, [{"position": Vector3(3.3, 1.58, 1.30), "action": "play", "wait": 20.0}])

func _spawn_cat(index: int, color: Color, staff: bool, routine: Array) -> void:
	var actor = Cat.new()
	actor.set_meta("cat_index", index)
	actor.set_meta("staff", staff)
	cast_root.add_child(actor)
	actor.build(color, staff)
	actor.scale = Vector3.ONE * (1.12 if staff else 1.40)
	actor.set_routine(routine)
	actors.append(actor)

func handle_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture or event is InputEventScreenDrag or (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		overview = false
	if event is InputEventMagnifyGesture:
		set_zoom(camera.size / maxf(event.factor,0.001))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(camera.size-0.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(camera.size+0.7)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pointer_start = event.position
				gesture_distance = 0
				dragging = true
			else:
				if dragging and gesture_distance < 10:
					_select(event.position)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		gesture_distance += event.relative.length()
		_pan(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1:
				pointer_start = event.position
				gesture_distance = 0
			else:
				gesture_distance = maxf(gesture_distance,10.0)
		else:
			if touches.size() == 1 and gesture_distance < 10:
				_select(event.position)
			touches.erase(event.index)
	elif event is InputEventScreenDrag:
		gesture_distance += event.relative.length()
		if touches.size() == 2:
			var points: Array = touches.values()
			var before: float = points[0].distance_to(points[1])
			touches[event.index] = event.position
			points = touches.values()
			var after: float = points[0].distance_to(points[1])
			if after > 1:
				set_zoom(camera.size*before/after)
		else:
			touches[event.index] = event.position
			_pan(event.relative)

func release_touch(index: int) -> void:
	touches.erase(index)

func _pan(relative: Vector2) -> void:
	overview = false
	var units := camera.size/get_viewport().get_visible_rect().size.x
	# Invert the ground projection so the scene follows the pointer on both axes.
	camera_target.x += (-relative.x/ISO_RIGHT.x+relative.y/ISO_UP.x)*0.5*units
	camera_target.z += (relative.x/ISO_RIGHT.x+relative.y/ISO_UP.x)*0.5*units
	camera_target.y = 0
	_update_camera()

func _select(screen_pos: Vector2) -> void:
	if build_mode:
		build_tapped.emit(screen_pos)
		return
	# Outdoor labels may be offset over the roof to stay legible. Their visible
	# buttons remain usable, while hidden room targets are never selectable.
	if exterior_view and neighborhood != null:
		for target in neighborhood.targets:
			if not contains_hotel(target.position) and target.get("screen_rect",Rect2()).has_point(screen_pos):
				grounds_selected.emit(target.action,target.payload)
				return
	if shell != null:
		if shell.select_door(screen_pos) or shell.roof_hit(screen_pos):
			return
	if neighborhood != null and neighborhood.select_at(screen_pos):
		return
	for actor in actors:
		if actor.visible and camera.unproject_position(actor.global_position + Vector3(0, 0.5, 0)).distance_to(screen_pos) < 28:
			if actor.is_staff:
				staff_selected.emit(int(actor.get_meta("cat_index")))
			else:
				cat_selected.emit(int(actor.get_meta("cat_index")))
			return
	if not exterior_view and room_builder != null:
		var selected: int = room_builder.room_at(screen_pos)
		if selected >= 0:
			room_selected.emit(selected)
			return
	var point = Plane(Vector3.UP, 0.2).intersects_ray(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))
	if point != null and absf(point.x) < 5.6 and point.z < -4.6 and point.z > -17.25:
		expansion_selected.emit(clampi(int((-point.z - 7.7) / 3.3), 0, 2))
		return
	if point == null or absf(point.x) > 5.6 or absf(point.z) > 4.6:
		return
	zone_selected.emit((0 if point.x < 0 else 1) if point.z < 0 else (3 if point.x < 0 else 2))





func _lamp_glow(p: Vector3) -> void:
	var gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0,0.18,0.55,1])
	gradient.colors = PackedColorArray([Color(1.0,0.87,0.52,0.5),Color(1.0,0.77,0.32,0.20),Color(1.0,0.72,0.25,0.06),Color(1,0.7,0.2,0)])
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	var glow = Sprite3D.new()
	glow.name = "LanternHalo"
	glow.texture = texture
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.pixel_size = 0.022
	glow.position = p + camera.global_basis.z * 0.25
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	building.add_child(glow)
	lamp_glows.append(glow)

func _light_pool(p: Vector3, dimensions: Vector2, panes: bool) -> void:
	var mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = dimensions
	mesh.mesh = plane
	mesh.position = p
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/light_pool.gdshader")
	material.set_shader_parameter("window_panes", panes)
	mesh.material_override = material
	building.add_child(mesh)
	light_pools.append({"material": material, "panes": panes})

func set_evening(enabled: bool) -> void:
	evening = enabled
	if environment_settings == null:
		return
	environment_settings.ambient_light_color = Color("a6b7d0") if evening else Color("e6edf0")
	environment_settings.ambient_light_energy = 0.31 if evening else 0.50
	sun.light_color = Color("aebee2") if evening else Color("fff4e6")
	sun.light_energy = 0.16 if evening else 0.28
	for lamp in lamps:
		lamp.light_energy = 0.83 if evening else 0.32
	for glow in lamp_glows:
		glow.modulate.a = 1.0 if evening else 0.58
		glow.scale = Vector3.ONE * (1.3 if evening else 1.0)
	for pool in light_pools:
		pool.material.set_shader_parameter("strength", (0.055 if evening else 0.11) if pool.panes else (0.30 if evening else 0.065))

func get_cat(index: int):
	for actor in actors:
		if not actor.is_staff and int(actor.get_meta("cat_index")) == index:
			return actor
	return null

func ensure_cat(index: int):
	var actor = get_cat(index)
	if actor != null:
		if not actor.visible:
			actor.visible = true
			actor.place_at(actor.position)
		return actor
	if index < 0 or index >= Content.CAT_NAMES.size():
		return null
	# A bounded cast; remove an unseen extra guest before adding another.
	if actors.size() >= 22:
		for candidate in actors.duplicate():
			if not candidate.is_staff and not candidate.visible:
				actors.erase(candidate)
				candidate.queue_free()
				break
		if actors.size() >= 22:
			return null
	# Unassigned arrivals wait around the courtyard until guest_visit gives
	# them a room route. Shared lobby endpoints otherwise jam the entrance.
	var waiting_spot := Vector3((index%6-2.5)*1.75,0.24,6.25+int(index/6)*2.25)
	_spawn_cat(index,Color(Content.COATS[index]),false,[{"position":waiting_spot,"action":"rest","wait":4.0+index%3}])
	var placed: Vector3 = actors[-1].position
	actors[-1].set_routine([{"position":placed,"action":"rest","wait":4.0+index%3,"allow_nearby":true},{"position":placed+Vector3(0,0,0.65),"action":"sniff","wait":5.0,"allow_nearby":true}])
	actors[-1].motion_enabled = motion_enabled
	return actors[-1]

func react_cat(index: int, pose: String, buddy: int = -1) -> void:
	var actor = ensure_cat(index)
	if actor == null or pose == "":
		return
	if pose == "friendship" and buddy >= 0:
		var other = ensure_cat(buddy)
		if other != null:
			transient_pairs.append({"a":actor,"b":other,"ap":actor.position,"bp":other.position,"ar":actor.rotation,"br":other.rotation,"left":7.0})
			actor.place_at(Vector3(-0.85,0.24,3.2))
			other.place_at(Vector3(0.85,0.24,3.2))
			actor.rotation.y = PI / 2
			other.rotation.y = -PI / 2
			other.react("friendship",7.0)
	actor.react(pose,7.0 if pose == "friendship" else 4.0)

func celebrate_build() -> void:
	for actor in actors:
		actor.react("construction" if actor.is_staff else "sniff",4.0)

func apply_life(model) -> void:
	if room_builder == null:
		room_builder = preload("res://scripts/world/room_builder.gd").new()
		room_builder.world = self
		add_child(room_builder)
	room_builder.sync(model)
	var cast_key: String = str(hotel_index)+str(Layout.entries(model,hotel_index))+":"+str(model.furniture.state.get("revision",0))
	if layout_cast_key != cast_key:
		layout_cast_key = cast_key
		_sync_layout_cats(model)
		if shell != null: shell.rebuild()
	set_exterior_view(false if build_mode else model.settings.exterior and not model.settings.watch)
	if neighborhood != null:
		neighborhood.sync(model)
	_sync_builders(model)
	var data: Dictionary = model.life.state.hotels[hotel_index]
	for actor in actors:
		if not actor.is_staff:
			var was_visible: bool = actor.visible
			actor.visible = model.life.known(int(actor.get_meta("cat_index"))) and (not build_mode or int(actor.get_meta("resident_room",-1)) != edited_room)
			if actor.visible and not was_visible:
				actor.place_at(actor.position)
	var key: String = str(hotel_index) + str(wings) + str(data.event) + str(data.stars)
	if key != life_key or not is_instance_valid(life_root):
		life_key = key
		if is_instance_valid(life_root):
			life_root.queue_free()
		life_root = Node3D.new()
		life_root.name = "PersonalFurniture"
		add_child(life_root)
		if not data.event.is_empty():
			for i in range(9):
				var item: String = "box" if data.event.id == "cardboard" else ("lamp" if data.event.id in ["lantern","spa"] else "sun_cushion")
				_furnishing(item,Vector3(-3.5 + (i%5)*1.65,0.12,6.0 + int(i/5)*1.2))
			for actor in actors:
				actor.react("celebrate",3.0)
		if data.stars > 0:
			for star in range(data.stars):
				_prop(Vector3(-0.5+star*0.25,1.85,4.8),Vector3(0.15,0.15,0.07),Color("edcb70"))
	event_active = not data.event.is_empty()
	weather_enabled = model.settings.weather
	if model.settings.watch and not build_mode:
		follow_cat = model.life.state.favorite
		ensure_cat(follow_cat)
	elif follow_cat >= 0:
		reset_camera()
	if weather_particles != null:
		weather_particles.emitting = weather_enabled and motion_enabled and hotel_index in [2,3]
		weather_particles.draw_pass_1.material.albedo_color = Color("cf9664") if hotel_index==2 else Color("f1f5f7")

func _sync_builders(model) -> void:
	var active_wing: int = wings if model.repair_remaining(hotel_index) > 0 else -1
	if active_wing != repair_wing or (active_wing >= 0 and not is_instance_valid(repair_root)):
		repair_wing = active_wing
		builders.clear()
		if is_instance_valid(repair_root):
			repair_root.queue_free()
		repair_root = Node3D.new()
		repair_root.name = "ConstructionCats"
		add_child(repair_root)
		if active_wing >= 0:
			for side in [-1, 1]:
				var builder = Cat.new()
				repair_root.add_child(builder)
				builder.build(Color("e3b477") if side < 0 else Color("939c8e"), true)
				builder.scale = Vector3.ONE * 1.55
				builder.place_at(Vector3(-3.6 if side < 0 else -1.3,0.24,-8.6-active_wing*3.3))
				builder.rotation.y = side * 0.6
				builder.react("construction", model.repair_remaining(hotel_index)+1)
				builder.thought.text = ""
				builders.append(builder)
	for builder in builders:
		builder.motion_enabled = motion_enabled
		# A static hard-hat pose remains visible with reduced motion enabled.
		builder.props.hat.visible = true
		builder.props.hammer.visible = true

func guest_visit(model, cat: int) -> void:
	var actor = ensure_cat(cat)
	if actor == null or actor.reaction != "":
		return
	_layout_visit(model,actor,cat)

func _layout_visit(model, actor, cat: int) -> void:
	var selected: int = model.life.best_room(model,hotel_index,cat)
	if selected < 0: selected = cat % maxi(1,model.room_count(hotel_index))
	_set_room_routine(model,actor,selected,true)

func _sync_layout_cats(model) -> void:
	room_centers.clear()
	for room in Layout.entries(model,hotel_index):
		room_centers.append(Layout.center(room))
	for room in range(model.room_count(hotel_index)):
		var cast_key := str(hotel_index)+str(Layout.entries(model,hotel_index)[room])+str(model.furniture.room_record(hotel_index,room).revision)
		if room_cast_keys.get(room,"")==cast_key: continue
		room_cast_keys[room]=cast_key
		var actor = ensure_cat(room % 12)
		actor.set_meta("resident_room",room)
		_set_room_routine(model,actor,room)

func _set_room_routine(model, actor, room: int, arriving: bool = false) -> void:
	var room_data: Dictionary = Layout.entries(model,hotel_index)[room]
	var instances: Array = model.furniture.room_items(hotel_index,room)
	var bed_instance := _first_instance(model,room,true)
	if bed_instance.is_empty(): return
	var bed_route: Array[Vector3] = Interior.route_to(room_data,instances,bed_instance.uid)
	var outer: Array = Layout.route_to_door(model,hotel_index,room)
	var guard := Interior.movement_guard(room_data,instances)
	var routine: Array = []
	var bed_walk := _walk_points(bed_route)
	var bed: Vector3 = bed_route[-1]
	routine.append({"position":bed,"action":"sleep","wait":12.0+room*2.0,"face":PI*0.25})
	routine.append({"position":bed,"action":"stretch","wait":3.0})
	var activity := _first_instance(model,room,false)
	var current_walk: Array = bed_walk
	if not activity.is_empty():
		var activity_route: Array[Vector3] = Interior.route_to(room_data,instances,activity.uid)
		# Leave the bed target through its approach before enabling the cell guard.
		if not bed_walk.is_empty(): routine.append({"position":bed_walk[-1],"action":"rest","wait":0.05})
		var return_inside: Array = bed_walk.duplicate(); return_inside.reverse()
		for index in range(1,return_inside.size()): routine.append({"position":return_inside[index],"action":"rest","wait":0.05,"guard":guard})
		var activity_walk := _walk_points(activity_route)
		for index in range(1,activity_walk.size()): routine.append({"position":activity_walk[index],"action":"rest","wait":0.05,"guard":guard})
		routine.append({"position":activity_route[-1],"action":str(Catalog.item(activity.item).pose),"wait":6.0})
		current_walk = activity_walk
	# Animation targets may be inside their objects; first return to the free approach.
	if not current_walk.is_empty(): routine.append({"position":current_walk[-1],"action":"rest","wait":0.05})
	var back: Array = current_walk.duplicate(); back.reverse()
	for index in range(1,back.size()): routine.append({"position":back[index],"action":"rest","wait":0.05,"guard":guard})
	var outer_back: Array = outer.duplicate(); outer_back.reverse()
	for point in outer_back: routine.append({"position":Vector3(point.x,0.24,point.y),"action":"rest","wait":0.05})
	routine.append({"position":Vector3(0,0.24,-3.85),"action":"rest","wait":0.05})
	routine.append({"position":Vector3(0,0.24,0.5),"action":"sniff","wait":4.0})
	routine.append({"position":Vector3(0,0.24,-3.85),"action":"rest","wait":0.05})
	for point in outer:
		routine.append({"position":Vector3(point.x,0.24,point.y),"action":"rest","wait":0.05})
	_append_interior_entry(routine,bed_walk,guard)
	routine.append({"position":bed,"action":"settle","wait":3.0})
	if arriving:
		var current: Vector3 = actor.position
		var outside: Vector2 = outer[0] if not outer.is_empty() else Vector2(current.x,current.z)
		var entrance_path: Array = preload("res://scripts/core/grounds_model.gd").route(Vector2(current.x,current.z),outside,model,hotel_index)
		var approach: Array = [{"position":current,"action":"arrival","wait":1.0}]
		for point in entrance_path:
			approach.append({"position":Vector3(point.x,0.24,point.y),"action":"rest","wait":0.05})
		for point in outer:
			approach.append({"position":Vector3(point.x,0.24,point.y),"action":"rest","wait":0.05})
		_append_interior_entry(approach,bed_walk,guard)
		approach.append_array(routine)
		# Leave the final bed pose through its own approach, then the doorway.
		if not bed_walk.is_empty(): approach.append({"position":bed_walk[-1],"action":"rest","wait":0.05})
		var exit_walk: Array = bed_walk.duplicate(); exit_walk.reverse()
		for index in range(1,exit_walk.size()): approach.append({"position":exit_walk[index],"action":"rest","wait":0.05,"guard":guard})
		for point in outer_back: approach.append({"position":Vector3(point.x,0.24,point.y),"action":"rest","wait":0.05})
		entrance_path.reverse()
		for point in entrance_path:
			approach.append({"position":Vector3(point.x,0.24,point.y),"action":"rest","wait":0.05})
		approach.append({"position":current,"action":"departure","wait":3.0})
		routine = approach
	actor.set_routine(routine)

func _append_interior_entry(routine: Array, walk: Array, guard: Callable) -> void:
	# The canonical bridge starts on the shell boundary. The apron is reserved
	# empty; enable the interior-cell guard after reaching its inside handoff.
	for index in range(walk.size()):
		var step := {"position":walk[index],"action":"rest","wait":0.05}
		if index>0: step.guard=guard
		routine.append(step)

func _first_instance(model, room: int, sleep: bool) -> Dictionary:
	for instance in model.furniture.room_items(hotel_index,room):
		var definition := Catalog.item(instance.item)
		if definition.interactive and bool(definition.provides_sleep) == sleep: return instance
	return {}

func _walk_points(route: Array) -> Array:
	var result := route.duplicate()
	if not result.is_empty(): result.pop_back()
	return result

func _public_lounge() -> void:
	# The old tiny starter bedrooms become a generous shared reading lounge.
	_rug(Vector3(-2.9,0.19,-2.15),Vector2(4.5,3.7),accent.darkened(0.08))
	for x in [-4.5,-1.65]:
		box(Vector3(x,0.50,-2.5),Vector3(0.95,0.5,1.6),Color("c88971"))
		box(Vector3(x,0.92,-3.18),Vector3(1.0,1.0,0.18),Color("d89b80"))
		box(Vector3(x,0.81,-2.65),Vector3(0.67,0.12,0.9),Color("e3b296"))
		plant(Vector3(x,0.24,-0.7),0.50)
	box(Vector3(-3.1,0.46,-2.2),Vector3(1.15,0.52,1.0),wood.darkened(0.12))
	box(Vector3(-3.1,0.75,-2.2),Vector3(1.35,0.12,1.15),wood)
	plant(Vector3(-3.1,0.82,-2.2),0.25)
	_lantern(Vector3(-5.15,1.4,-3.6))
	box(Vector3(-2.8,0.4,-3.2),Vector3(2.2,0.6,0.5),wood)
	for i in range(8):
		box(Vector3(-3.7+i*0.24,0.91,-3.2),Vector3(0.16,0.52,0.34),[Color("9fae83"),Color("c88e74"),Color("d4bc87")][i%3])


func _prop(pos: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	mesh.mesh = cube
	mesh.position = pos
	mesh.scale = dimensions
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material_override = mat
	life_root.add_child(mesh)
	return mesh

func _furnishing(id: String, p: Vector3) -> void:
	match id:
		"mat", "sun_cushion", "heated", "blanket":
			_prop(p+Vector3(0,0.07,0),Vector3(0.63,0.13,0.6),Color("d7b778") if id=="sun_cushion" else (Color("b4bccd") if id=="heated" else Color("dce2c8")))
			_prop(p+Vector3(0,0.16,-0.20),Vector3(0.43,0.1,0.18),Color("fff1d3"))
		"cave":
			for x in [-0.3,0.3]:
				_prop(p+Vector3(x,0.2,0),Vector3(0.10,0.4,0.6),Color("bd9e83"))
			_prop(p+Vector3(0,0.42,0),Vector3(0.7,0.12,0.6),Color("e0c6ab"))
		"box":
			for x in [-0.25,0.25]:
				_prop(p+Vector3(x,0.16,0),Vector3(0.06,0.32,0.55),Color("b99161"))
			_prop(p+Vector3(0,0.16,-0.25),Vector3(0.55,0.32,0.06),Color("c7a06b"))
		"perch", "tower", "table":
			var h: float = 1.05 if id=="tower" else 0.48
			_prop(p+Vector3(0,h/2,0),Vector3(0.12,h,0.12),wood)
			_prop(p+Vector3(0,h,0),Vector3(0.7,0.13,0.6),accent)
			if id=="tower":
				_prop(p+Vector3(0.2,0.53,0),Vector3(0.65,0.1,0.5),Color("c5b59a"))
		"tunnel":
			for x in [-0.26,0.26]:
				_prop(p+Vector3(x,0.19,0),Vector3(0.09,0.38,0.8),accent)
			_prop(p+Vector3(0,0.39,0),Vector3(0.62,0.1,0.8),accent.lightened(0.1))
		"rug":
			_prop(p+Vector3(0,0.02,0),Vector3(0.75,0.04,0.66),Color("b7c2ad"))
		"scratch":
			_prop(p+Vector3(0,0.35,0),Vector3(0.15,0.7,0.15),Color("d8c39a"))
			_prop(p,Vector3(0.5,0.08,0.5),wood)
		"lamp":
			_prop(p+Vector3(0,0.2,0),Vector3(0.3,0.4,0.3),Color("efc675"))
			_prop(p+Vector3(0,0.44,0),Vector3(0.36,0.06,0.36),trim)
		"plant", "flowers":
			_prop(p+Vector3(0,0.13,0),Vector3(0.3,0.26,0.3),Color("b78365"))
			_prop(p+Vector3(0,0.37,0),Vector3(0.38,0.28,0.4),accent)
			if id=="flowers":
				_prop(p+Vector3(0,0.54,0),Vector3(0.15,0.12,0.2),Color("eed7ae"))

func _setup_weather() -> void:
	weather_particles = GPUParticles3D.new()
	weather_particles.name = "SeasonalWeather"
	weather_particles.amount = 60
	weather_particles.lifetime = 9.0
	weather_particles.position = Vector3(0,6,0)
	weather_particles.visibility_aabb = AABB(Vector3(-12,-10,-12),Vector3(24,20,24))
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(9,1,9)
	material.gravity = Vector3(0,-0.15,0)
	material.direction = Vector3(0,-1,0)
	material.initial_velocity_min = 0.2
	material.initial_velocity_max = 0.6
	material.scale_min = 0.035
	material.scale_max = 0.075
	weather_particles.process_material = material
	var particle_mesh = BoxMesh.new()
	var paint = StandardMaterial3D.new()
	paint.albedo_color = Color("efe7d7")
	particle_mesh.material = paint
	weather_particles.draw_pass_1 = particle_mesh
	weather_particles.emitting = false
	add_child(weather_particles)

func _process(delta: float) -> void:
	for pair in transient_pairs.duplicate():
		pair.left -= delta
		if pair.left <= 0:
			if is_instance_valid(pair.a):
				pair.a.place_at(pair.ap)
				pair.a.rotation = pair.ar
			if is_instance_valid(pair.b):
				pair.b.place_at(pair.bp)
				pair.b.rotation = pair.br
			transient_pairs.erase(pair)
	if not motion_enabled:
		return
	if follow_cat >= 0:
		var actor = get_cat(follow_cat)
		if actor != null:
			camera_target = camera_target.lerp(actor.position+Vector3(0,0.6,0),minf(1,delta*2.0))
			camera.size = lerpf(camera.size,6.0,minf(1,delta*1.5))
			_update_camera()
	ambient_clock += delta
	if ambient_clock > 16.0:
		ambient_clock = 0.0
		var guests: Array = actors.filter(func(actor): return actor.visible and not actor.is_staff and actor.reaction == "")
		if guests.size() > 0:
			var index: int = int(Time.get_ticks_msec()/16000) % guests.size()
			guests[index].react(["groom","yawn","stretch","box","blanket","zoomies","missed_jump"][index%7],4.0)


func focus_grounds() -> void:
	follow_cat = -1
	overview = false
	camera_target = Vector3(0,0,1.0)
	camera.size = 26.0
	_update_camera()
