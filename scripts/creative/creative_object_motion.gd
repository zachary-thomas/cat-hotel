extends Node3D
## Reusable rigid-cube animation for one furniture object. LifePart contains the
## actual authored geometry extracted from the parent's static batches.

var shape: String = ""
var motion_enabled: bool = true
var effects_visible: bool = true
var action: String = ""
var activity_elapsed: float = 0.0
var activity_token: String = ""
var burst_count: int = 0

var _time: float = 0.0
var _last_activity_elapsed: float = 0.0
var _part: Node3D
var _part_rest: Transform3D
var _effects: Dictionary = {}
var _visible_counts: Dictionary = {}
var _bases: Dictionary = {}
var _effect_positions: Dictionary = {}
var _flame_heights: Array[float] = []
var _burst_start_elapsed: float = -1.0
var _part_materials: Array[ShaderMaterial] = []
var _part_tints: Array[Color] = []
var _phase_offset: float = 0.0

func _ready() -> void:
	# Godot auto-enables scripts that define _process when they enter the tree.
	_refresh_processing()

func configure(object_shape: String, footprint: Vector2) -> void:
	shape = object_shape
	_part = get_parent().get_node_or_null("LifePart")
	if _part == null:
		_part = Node3D.new()
		_part.name = "LifePart"
		get_parent().add_child(_part)
	_build_for_shape(footprint)
	if shape == "fireplace": _initialize_static_fire()
	_part_rest = _part.transform
	_prepare_part_materials()
	_refresh_processing()

func set_phase_seed(seed: int) -> void:
	# Stable IDs can use String.hash(); the modulo keeps large hashes numerically tame.
	_phase_offset = float(posmod(seed,4096))/4096.0*TAU

func set_activity(next_action: String, elapsed: float, token: String) -> void:
	var changed: bool = next_action != action or token != activity_token or elapsed < _last_activity_elapsed
	action = next_action
	activity_token = token
	activity_elapsed = maxf(0.0,elapsed)
	if changed:
		_last_activity_elapsed = activity_elapsed
		_hide_activity_effects()
		_cancel_burst()
	elif effects_visible and motion_enabled:
		_check_markers(_last_activity_elapsed,activity_elapsed)
	_last_activity_elapsed = activity_elapsed
	if shape == "litter" and _burst_start_elapsed >= 0.0 and motion_enabled and effects_visible: _update_litter_burst()
	if action.is_empty():
		_restore_part()
	elif shape in ["mat","sun_cushion","heated","blanket","cave","canopy_bed","cloud_sofa","lounge_sofa"] and action in ["sleep","rest"]:
		_part.scale.y = 0.965
	_refresh_processing()

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled
	if not enabled:
		_restore_part()
		_hide_all_bursts()
		_cancel_burst()
	_refresh_processing()
	_sync_spillways()

func set_effects_visible(enabled: bool) -> void:
	effects_visible = enabled
	for node in _effects.values():
		(node as GeometryInstance3D).visible = enabled
	if not enabled:
		_hide_all_bursts()
		_cancel_burst()
	_refresh_processing()
	_sync_spillways()

func _sync_spillways() -> void:
	var spillways: Node = get_parent().get_node_or_null("VoxelSpillways") if get_parent() else null
	if spillways:
		spillways.visible = effects_visible
		spillways.set_motion_enabled(motion_enabled and effects_visible)

func _process(delta: float) -> void:
	if not motion_enabled or not effects_visible: return
	_time += delta
	_update_ambient()
	_update_activity()
	_refresh_processing()

func _refresh_processing() -> void:
	var ambient: bool = shape in ["fireplace","fountain","plant","garden_planter","shrub","flowers","flower_bed","tree","lamp","garden_lamp"]
	var active_process: bool = _requires_activity_process()
	var burst_process: bool = shape=="litter" and _burst_start_elapsed>=0.0
	set_process(motion_enabled and effects_visible and (ambient or active_process or burst_process))

func _requires_activity_process() -> bool:
	if shape in ["mat","sun_cushion","heated","blanket","cave","canopy_bed","cloud_sofa","lounge_sofa"]: return action=="knead"
	return _is_active_action()

func _build_for_shape(footprint: Vector2) -> void:
	match shape:
		"fireplace":
			_make_batch("flames",3,Color("f5a94f"),true)
			_make_batch("embers",8,Color("ef7a43"),true)
		"fountain":
			_make_batch("spout",5,Color("a8e9df"),true)
			_make_batch("splash",12,Color("83d4d0"),true)
		"milkshake_counter":
			_make_batch("foam",8,Color("fff1df"),true)
		"scratch":
			_make_batch("fibers",10,Color("d8bd91"),true)
		"litter": _make_batch("burst",12,Color("d4b27e"),true)

func _prepare_part_materials() -> void:
	if shape not in ["lamp","garden_lamp"]: return
	for child in _part.get_children():
		if child is MultiMeshInstance3D and child.material_override is ShaderMaterial:
			var material: ShaderMaterial = child.material_override.duplicate()
			child.material_override = material
			_part_materials.append(material)
			_part_tints.append(material.get_shader_parameter("tint"))

func _make_batch(key: String, count: int, color: Color, initially_hidden: bool) -> void:
	var batch: MultiMeshInstance3D = _new_batch(count,color)
	batch.name = "Voxel"+key.capitalize()
	add_child(batch)
	_effects[key] = batch
	var positions: Array[Vector3] = []
	positions.resize(count)
	positions.fill(Vector3.ZERO)
	_effect_positions[key] = positions
	_visible_counts[key] = 0 if initially_hidden else count
	_bases[key] = []
	_hide_batch(key)

func _new_batch(count: int, color: Color) -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	var cube := BoxMesh.new(); cube.size = Vector3.ONE
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_colors = true
	mesh.mesh = cube
	mesh.instance_count = count
	batch.multimesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.72
	material.emission_enabled = true
	material.emission = color.darkened(0.25)
	material.emission_energy_multiplier = 0.18
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(count): mesh.set_instance_color(i,color)
	return batch

func _update_ambient() -> void:
	var clock: float = _time+_phase_offset
	if shape == "fireplace":
		var flames: MultiMeshInstance3D = _effects.flames
		_visible_counts.flames = 3
		_flame_heights.clear()
		for i in range(3):
			var height: float = 0.22+0.12*(0.5+0.5*sin(clock*6.2+float(i)*1.8))
			_flame_heights.append(height)
			var at := Vector3((-0.18+float(i)*0.205)*float(get_parent().get_meta("footprint",Vector2.ONE).x),0.20+height*0.5,float(get_parent().get_meta("footprint",Vector2.ONE).y)*0.50)
			flames.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(0.13,height,0.085)),at))
			flames.multimesh.set_instance_color(i,[Color("ffd36d"),Color("f5a94f"),Color("ee7446")][posmod(int(clock*8.0)+i,3)])
		var ember_count: int = 5+int(clock*1.7)%4
		_visible_counts.embers = ember_count
		var embers: MultiMeshInstance3D = _effects.embers
		for i in range(8):
			if i >= ember_count: embers.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO)); continue
			var phase: float = fposmod(clock*0.38+float(i)*0.137,1.0)
			var e_at := Vector3((float((i*5)%7)/6.0-0.5)*0.48,0.35+phase*0.62,float(get_parent().get_meta("footprint",Vector2.ONE).y)*0.51)
			embers.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(0.025+0.014*(i%2))),e_at))
	elif shape == "fountain":
		_visible_counts.spout = 5; _visible_counts.splash = 12
		var spout: MultiMeshInstance3D = _effects.spout
		for i in range(5):
			var h: float = 0.10+float(i)*0.095+sin(clock*3.5+float(i)*0.4)*0.022
			spout.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(0.07,0.12,0.07)),Vector3(0,2.05+h,0)))
		var splash: MultiMeshInstance3D = _effects.splash
		for i in range(12):
			var phase := fposmod(clock*0.7+float(i)/12.0,1.0)
			var angle := float(i)*TAU/12.0
			var radius := 0.09+phase*0.25
			var at := Vector3(cos(angle)*radius,1.91+sin(phase*PI)*0.13,sin(angle)*radius)
			splash.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.045),at))
	elif shape in ["plant","garden_planter","shrub","flowers","flower_bed","tree"]:
		_part.rotation.z = sin(clock*0.72)*0.025
	elif shape in ["lamp","garden_lamp"]:
		_part.scale = Vector3.ONE*(1.0+sin(clock*1.1)*0.012)
		var glow: float = 0.03+0.055*(0.5+0.5*sin(clock*1.1))
		for i in range(_part_materials.size()): _part_materials[i].set_shader_parameter("tint",_part_tints[i].lightened(glow))
	if shape == "litter" and _burst_start_elapsed >= 0.0: _update_litter_burst()

func _initialize_static_fire() -> void:
	_visible_counts.flames = 3
	_flame_heights = [0.28,0.34,0.25]
	var flames: MultiMeshInstance3D = _effects.flames
	var footprint: Vector2 = get_parent().get_meta("footprint",Vector2.ONE)
	for i in range(3):
		var height: float=_flame_heights[i]
		var at:=Vector3((-0.18+float(i)*0.205)*footprint.x,0.20+height*0.5,footprint.y*0.50)
		flames.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(0.13,height,0.085)),at))
		flames.multimesh.set_instance_color(i,[Color("ffd36d"),Color("f5a94f"),Color("ee7446")][i])
	_hide_batch("embers")

func _update_activity() -> void:
	var clock: float = _time+_phase_offset
	var active: bool = _is_active_action()
	if not active:
		if not action.is_empty(): _restore_part()
		return
	match shape:
		"milkshake_counter":
			_part.position = Vector3(sin(clock*34.0)*0.018,0,cos(clock*29.0)*0.012)
			var foam: MultiMeshInstance3D = _effects.foam
			_visible_counts.foam = 8
			for i in range(8):
				var f_phase := fposmod(clock*0.9+float(i)/8.0,1.0)
				var anchor: Vector3 = _part.get_meta("effect_anchor",Vector3.ZERO)
				var f_at := anchor+Vector3((float(i%3)-1.0)*0.045,f_phase*0.16,(float(i%2)-0.5)*0.06)
				_set_effect_transform("foam",i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.035),f_at))
		"box": _part.rotation.x = -0.18+sin(clock*5.0)*0.12
		"scratch":
			_part.rotation.z = sin(clock*13.0)*0.035
			var fibers: MultiMeshInstance3D = _effects.fibers
			_visible_counts.fibers = 10
			for i in range(10):
				var fiber_at := Vector3((float(i%5)-2.0)*0.035,0.30+float(i/5)*0.24,(float(i%2)-0.5)*0.14)
				fibers.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(0.018,0.045,0.018)),fiber_at))
		"tunnel", "playpen": _part.position.y = absf(sin(clock*5.0))*0.13
		"mat", "sun_cushion", "heated", "blanket", "cave", "canopy_bed", "cloud_sofa", "lounge_sofa": _part.scale.y = 0.965+sin(clock*4.0)*0.012
		"reception_counter": _part.position.y = absf(sin(clock*8.0))*0.07

func _is_active_action() -> bool:
	match shape:
		"milkshake_counter": return action == "serve"
		"box": return action == "peek"
		"scratch": return action == "scratch"
		"tunnel", "playpen": return action == "play"
		"mat", "sun_cushion", "heated", "blanket", "cave", "canopy_bed", "cloud_sofa", "lounge_sofa": return action in ["knead","sleep","rest"]
		"reception_counter": return action == "greet"
	return false

func _check_markers(previous: float, current: float) -> void:
	if shape != "litter" or action != "dig": return
	for marker in [1.1,2.3,3.5]:
		if previous < marker and current >= marker:
			_emit_litter_burst(marker)

func _emit_litter_burst(marker: float) -> void:
	burst_count += 1
	_burst_start_elapsed = marker
	_visible_counts.burst = 12
	_update_litter_burst()

func _update_litter_burst() -> void:
	var age: float = activity_elapsed-_burst_start_elapsed
	if age < 0.0 or age >= 0.58:
		_hide_batch("burst")
		_burst_start_elapsed = -1.0
		return
	var batch: MultiMeshInstance3D = _effects.burst
	var footprint: Vector2 = get_parent().get_meta("footprint",Vector2.ONE)
	for i in range(12):
		var angle := float(i)*TAU/12.0+_burst_start_elapsed
		var radius := 0.09+float(i%4)*0.035+age*0.38
		var lift := sin(age/0.58*PI)*0.20
		var at := Vector3(cos(angle)*radius,0.45+lift+float(i%3)*0.035,footprint.y*0.42+sin(angle)*radius)
		var size := (0.035+float(i%2)*0.018)*(1.0-age/0.58)
		_set_effect_transform("burst",i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),at))

func _hide_activity_effects() -> void:
	for key in ["foam","fibers","burst"]:
		if _effects.has(key): _hide_batch(key)

func _hide_all_bursts() -> void:
	for key in ["embers","splash","foam","fibers","burst"]:
		if _effects.has(key): _hide_batch(key)

func _cancel_burst() -> void:
	_burst_start_elapsed = -1.0
	if _effects.has("burst"): _hide_batch("burst")

func _hide_batch(key: String) -> void:
	var batch: MultiMeshInstance3D = _effects[key]
	_visible_counts[key] = 0
	for i in range(batch.multimesh.instance_count): batch.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),Vector3.ZERO))

func _set_effect_transform(key: String, index: int, transform: Transform3D) -> void:
	var positions: Array[Vector3] = _effect_positions[key]
	positions[index] = transform.origin
	_effect_positions[key] = positions
	(_effects[key] as MultiMeshInstance3D).multimesh.set_instance_transform(index,transform)

func _restore_part() -> void:
	if _part: _part.transform = _part_rest

func effect_capacity(key: String) -> int:
	return (_effects[key] as MultiMeshInstance3D).multimesh.instance_count if _effects.has(key) else 0

func visible_effect_count(key: String) -> int:
	return int(_visible_counts.get(key,0))

func effect_transform(key: String, index: int) -> Transform3D:
	return (_effects[key] as MultiMeshInstance3D).multimesh.get_instance_transform(index)

func effect_node(key: String) -> MultiMeshInstance3D:
	return _effects.get(key)

func part_transform() -> Transform3D:
	return _part.transform

func rest_part_transform() -> Transform3D:
	return _part_rest

func flame_height(index: int) -> float:
	return _flame_heights[index] if index >= 0 and index < _flame_heights.size() else 0.0

func actual_part_node() -> Node3D:
	return _part

func actual_part_kind() -> String:
	return String(_part.get_meta("part_kind",""))

func actual_part_cube_count() -> int:
	var count: int = 0
	for child in _part.get_children():
		if child is MultiMeshInstance3D: count += child.multimesh.instance_count
	return count

func effect_position(key: String, index: int) -> Vector3:
	var positions: Array[Vector3] = _effect_positions.get(key,[])
	return positions[index] if index >= 0 and index < positions.size() else Vector3.ZERO

func part_effect_anchor() -> Vector3:
	return _part.get_meta("effect_anchor",Vector3.ZERO)
