extends MultiMeshInstance3D
## Each droplet remains a rigid cube; one batch animates all four spillways.
var motion_enabled: bool = true
var _elapsed: float = 0.0
var _width: float = 1.0
var _depth: float = 1.0
var _drops: Array[Dictionary] = []

func build(width: float, depth: float) -> void:
	_width = width
	_depth = depth
	var cube = BoxMesh.new()
	cube.size = Vector3.ONE
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = cube
	for tier in range(2):
		for side in range(4):
			for step in range(7):
				_drops.append({"tier":tier,"side":side,"phase":float(step)/7.0})
	multimesh.instance_count = _drops.size()
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = Color("2c666d")
	material.emission_energy_multiplier = 0.16
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(_drops.size()): multimesh.set_instance_color(i,Color("b2e9df") if i%3==0 else Color("74c5c5"))
	_update_drops()

func set_motion_enabled(enabled: bool) -> void:
	motion_enabled = enabled

func _process(delta: float) -> void:
	if not motion_enabled: return
	_elapsed += delta
	_update_drops()

func _update_drops() -> void:
	for i in range(_drops.size()):
		var drop: Dictionary = _drops[i]
		var t: float = fposmod(float(drop.phase)+_elapsed*0.62,1.0)
		var upper: bool = int(drop.tier)==1
		var top: float = 1.87 if upper else 1.20
		var bottom: float = 1.20 if upper else 0.36
		var radius: float = (0.14 if upper else 0.32)+t*0.075
		var at: Vector3 = Vector3(0,lerpf(top,bottom,t*t),0)
		match int(drop.side):
			0: at.x = _width*radius
			1: at.x = -_width*radius
			2: at.z = _depth*radius
			3: at.z = -_depth*radius
		var side: float = 0.065+float(i%3)*0.016
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(side,side*1.35,side)),at))
