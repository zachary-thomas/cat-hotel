extends Control
## Small isometric catalogue illustrations, matching the room's furniture palettes.
var item_id: String = "mat":
	set(value):
		item_id = value
		queue_redraw()
const WOOD = Color("ad8058")
const GREEN = Color("91a47f")
const LINEN = Color("f7eed8")

func _init() -> void:
	custom_minimum_size = Vector2(56, 56)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var factor: float = minf(size.x, size.y) / 56.0
	if factor <= 0:
		return
	draw_set_transform((size - Vector2.ONE * 56.0 * factor) / 2.0, 0, Vector2.ONE * factor)
	draw_circle(Vector2(28, 28), 25, Color("eee7d3"))
	_poly([Vector2(9, 39), Vector2(28, 49), Vector2(48, 39), Vector2(28, 30)], Color("d8d0b6"))
	match item_id:
		"mat", "sun_cushion", "cave", "heated", "blanket": _bed()
		"box":
			_cube(Vector3(0, 0, 0), Vector3(2.5, 0.12, 2.0), Color("9e744d"))
			_cube(Vector3(0, 0.12, -0.94), Vector3(2.5, 1.55, 0.12), Color("c29967"))
			_cube(Vector3(-1.19, 0.12, 0), Vector3(0.12, 1.55, 2.0), Color("bb8d5c"))
			_cube(Vector3(1.19, 0.12, 0), Vector3(0.12, 1.55, 2.0), Color("d4ae79"))
			_cube(Vector3(0, 0.12, 0.94), Vector3(2.5, 1.55, 0.12), Color("d4ae79"))
			_cube(Vector3(-1.53, 1.68, 0), Vector3(0.70, 0.06, 2.0), Color("cda674"))
			_cube(Vector3(0.25, 0.69, 1.025), Vector3(0.88, 0.52, 0.025), LINEN)
		"perch":
			_cube(Vector3.ZERO, Vector3(2.4, 0.18, 1.8), WOOD)
			for x in [-0.72, 0.72]:
				_cube(Vector3(x, 0.18, 0), Vector3(0.26, 2.30, 0.30), Color("c5b28c"))
			_cube(Vector3(0, 2.4, 0), Vector3(2.8, 0.18, 1.95), WOOD)
			_cube(Vector3(0, 2.58, 0), Vector3(2.5, 0.25, 1.65), Color("e4c987"))
		"tower":
			_cube(Vector3.ZERO, Vector3(2.6, 0.18, 2.1), GREEN)
			_cube(Vector3(0.62, 0.18, -0.3), Vector3(0.28, 2.85, 0.30), Color("c3b08c"))
			_cube(Vector3(-0.65, 0.18, 0.30), Vector3(0.28, 1.45, 0.30), Color("c3b08c"))
			_cube(Vector3(-0.62, 1.5, 0.30), Vector3(1.65, 0.23, 1.55), GREEN)
			_cube(Vector3(0.60, 2.85, -0.3), Vector3(1.70, 0.24, 1.65), GREEN)
			_cube(Vector3(0.60, 3.09, -0.3), Vector3(1.4, 0.12, 1.35), LINEN)
		"tunnel":
			_cube(Vector3.ZERO, Vector3(3.0, 0.14, 1.8), Color("a28373"))
			_cube(Vector3(0, 0.14, -0.78), Vector3(3.0, 1.25, 0.24), Color("bb9c87"))
			_cube(Vector3(0, 0.14, 0.78), Vector3(3.0, 1.25, 0.24), Color("bb9c87"))
			_cube(Vector3(0, 1.39, 0), Vector3(3.0, 0.25, 1.8), Color("cdb199"))
			for x in [-1.05, 1.05]:
				_cube(Vector3(x, 1.64, 0), Vector3(0.19, 0.10, 1.85), LINEN)
		"table":
			for z in [-1.05, 1.05]:
				for x in [-0.9, 0.9]:
					_cube(Vector3(x, 0, z), Vector3(0.19, 0.60, 0.23), WOOD)
				_cube(Vector3(0, 0.60, z), Vector3(2.75, 0.16, 0.50), Color("c6a275"))
			_table(Vector3.ZERO, Vector2(2.6, 1.6), 1.50)
			_cube(Vector3(0.45, 1.69, 0.12), Vector3(0.65, 0.10, 0.65), LINEN)
		"plant": _plant(Vector3.ZERO)
		"rug":
			_cube(Vector3.ZERO, Vector3(3.3, 0.08, 2.8), Color("7f9a8b"))
			_cube(Vector3(0, 0.08, 0), Vector3(2.95, 0.04, 2.45), Color("b3c2ad"))
			for z in [-0.90, 0.90]:
				_cube(Vector3(0, 0.12, z), Vector3(2.75, 0.025, 0.10), LINEN)
			for x in [-1.30, -0.65, 0, 0.65, 1.30]:
				for z in [-1.48, 1.48]:
					_cube(Vector3(x, 0, z), Vector3(0.13, 0.07, 0.24), LINEN)
		"scratch":
			_cube(Vector3.ZERO, Vector3(2.1, 0.20, 1.85), WOOD)
			_cube(Vector3(0, 0.20, 0), Vector3(0.65, 2.65, 0.65), Color("d2bb8f"))
			for i in range(10):
				_cube(Vector3(0, 0.32 + i * 0.24, 0), Vector3(0.70, 0.06, 0.70), Color("ae9266"))
			_cube(Vector3(0, 2.85, 0), Vector3(1.0, 0.18, 1.0), GREEN)
		"lamp":
			_cube(Vector3.ZERO, Vector3(1.60, 0.18, 1.4), Color("9e8556"))
			_cube(Vector3(0, 0.18, 0), Vector3(0.15, 2.40, 0.15), Color("a58b54"))
			_cube(Vector3(0, 2.40, 0), Vector3(1.9, 0.85, 1.75), Color("f7d994"))
			_cube(Vector3(0, 3.25, 0), Vector3(1.4, 0.12, 1.3), Color("e8c787"))
		"flowers":
			_table(Vector3.ZERO, Vector2(1.65, 1.45), 0.80)
			_cube(Vector3(0, 0.98, 0), Vector3(0.72, 0.77, 0.70), Color("a9c1b2"))
			for i in range(5):
				var p: Vector3 = Vector3((i % 3 - 1) * 0.45, 1.6, float(i / 3) * 0.55 - 0.25)
				_cube(p, Vector3(0.07, 1.05, 0.07), GREEN)
				p.y += 0.75 + (i % 2) * 0.26
				_cube(p, Vector3(0.60, 0.36, 0.58), Color("dca391") if i % 2 else Color("ebc96f"))
		"cloud_sofa", "suite_sofa": _sofa(item_id == "cloud_sofa")
		"adventure_tree": _adventure_tree()
		"canopy_bed": _canopy_bed()
		"room_nightstand":
			_cube(Vector3.ZERO, Vector3(1.35, 1.05, 1.25), WOOD)
			_cube(Vector3(0, 1.05, 0), Vector3(1.52, 0.14, 1.42), Color("d5b27e"))
			_cube(Vector3(0, 1.19, 0), Vector3(0.12, 0.70, 0.12), Color("a88d58"))
			_cube(Vector3(0, 1.89, 0), Vector3(1.10, 0.50, 1.0), Color("f5d78e"))
		"suite_table": _table(Vector3.ZERO, Vector2(2.35, 2.05), 1.35)
	draw_set_transform(Vector2.ZERO)

func _sofa(premium: bool) -> void:
	var upholstery: Color = Color("91aa9a") if premium else Color("a6b292")
	_cube(Vector3.ZERO, Vector3(3.1, 0.42, 1.75), upholstery.darkened(0.10))
	_cube(Vector3(0, 0.42, 0.62), Vector3(3.1, 1.08, 0.34), upholstery)
	for x in [-1.32, 1.32]:
		_cube(Vector3(x, 0.35, 0), Vector3(0.38, 0.90, 1.72), upholstery.darkened(0.15))
	for x in [-0.64, 0.64]:
		_cube(Vector3(x, 0.48, -0.12), Vector3(1.15, 0.24, 1.20), LINEN if premium else Color("cbd2b7"))
		_cube(Vector3(x, 0.92, 0.38), Vector3(0.62, 0.55, 0.31), Color("e8bd91"))

func _adventure_tree() -> void:
	_cube(Vector3.ZERO, Vector3(3.0, 0.18, 2.75), GREEN)
	for post in [Vector3(-0.75,0.18,-0.35), Vector3(0.62,0.18,0.25)]:
		_cube(post, Vector3(0.30, 3.25 if post.x < 0 else 2.35, 0.30), Color("c4ad83"))
	_cube(Vector3(0.55, 2.35, 0.25), Vector3(1.55, 0.25, 1.45), Color("bdc79e"))
	_cube(Vector3(-0.75, 3.43, -0.35), Vector3(1.65, 0.25, 1.55), Color("9caf7e"))
	_cube(Vector3(-0.75, 3.68, -0.35), Vector3(1.35, 0.16, 1.25), LINEN)
	_cube(Vector3(0.65, 0.25, 0.75), Vector3(1.35, 1.25, 1.10), Color("bd9577"))

func _canopy_bed() -> void:
	_bed()
	for x in [-1.22, 1.22]:
		for z in [-1.48, 1.48]:
			_cube(Vector3(x, 0, z), Vector3(0.15, 3.45, 0.15), Color("a97758"))
	_cube(Vector3(0, 3.45, 0), Vector3(2.62, 0.20, 3.12), Color("dbc5ad"))
	for x in [-1.27, 1.27]:
		_cube(Vector3(x, 2.40, -0.85), Vector3(0.10, 1.65, 0.75), Color("f0dfcc"))

func _bed() -> void:
	var color: Color = Color("c6c6a7")
	match item_id:
		"sun_cushion": color = Color("e7bc62")
		"cave": color = Color("ac9696")
		"heated": color = Color("e7bfa1")
		"blanket": color = Color("8ca7a1")
	_cube(Vector3(0, 0.08, 0), Vector3(2.4, 0.36, 3.05), WOOD)
	_cube(Vector3(0, 0.25, -1.47), Vector3(2.45, 1.55, 0.20), Color("b8956c"))
	_cube(Vector3(0, 0.46, 0), Vector3(2.28, 0.38, 2.85), LINEN)
	_cube(Vector3(0, 0.84, 0.48), Vector3(2.30, 0.16, 1.92), color)
	_cube(Vector3(0, 1.0, -0.39), Vector3(2.32, 0.09, 0.30), color.lightened(0.20))
	for x in [-0.57, 0.57]:
		_cube(Vector3(x, 0.84, -0.94), Vector3(0.91, 0.25, 0.63), Color("fff9e7"))
	if item_id == "cave":
		for x in [-1.15, 1.15]:
			_cube(Vector3(x, 0.80, -0.82), Vector3(0.17, 1.45, 1.22), color)
		_cube(Vector3(0, 2.25, -0.82), Vector3(2.53, 0.18, 1.40), color.lightened(0.14))
	elif item_id == "blanket":
		for z in [0.04, 0.63, 1.23]:
			_cube(Vector3(0, 1.005, z), Vector3(2.32, 0.035, 0.13), LINEN)
	elif item_id == "sun_cushion":
		_cube(Vector3(0, 1.01, 0.45), Vector3(1.17, 0.32, 1.04), Color("f8d979"))
	elif item_id == "heated":
		_cube(Vector3(0, 0.50, 1.54), Vector3(1.95, 0.10, 0.04), Color("ffd365"))
		_cube(Vector3(0.85, 1.01, 0.89), Vector3(0.25, 0.08, 0.37), Color("ae826d"))

func _plant(p: Vector3) -> void:
	_cube(p, Vector3(1.25, 0.95, 1.15), Color("c59271"))
	_cube(p + Vector3(0, 0.95, 0), Vector3(1.4, 0.18, 1.3), Color("d5aa86"))
	_cube(p + Vector3(0, 1.1, 0), Vector3(0.16, 1.45, 0.16), Color("7d8d5e"))
	for leaf in [Vector3(-0.6, 1.7, 0), Vector3(0.5, 2.1, 0.15), Vector3(0, 2.65, -0.25), Vector3(0.03, 1.6, 0.60)]:
		_cube(p + leaf, Vector3(1.0, 0.52, 0.87), GREEN if leaf.y < 2.0 else Color("a6b680"))

func _table(p: Vector3, dimensions: Vector2, h: float) -> void:
	for x in [-dimensions.x * 0.35, dimensions.x * 0.35]:
		for z in [-dimensions.y * 0.32, dimensions.y * 0.32]:
			_cube(p + Vector3(x, 0, z), Vector3(0.18, h, 0.18), WOOD)
	_cube(p + Vector3(0, h, 0), Vector3(dimensions.x, 0.18, dimensions.y), Color("cca677"))

func _point(p: Vector3) -> Vector2:
	return Vector2(28 + (p.x - p.z) * 7.3, 39 + (p.x + p.z) * 3.5 - p.y * 8.0)

func _cube(p: Vector3, dimensions: Vector3, color: Color) -> void:
	var a: Vector3 = p + Vector3(-dimensions.x / 2.0, dimensions.y, -dimensions.z / 2.0)
	var b: Vector3 = p + Vector3(dimensions.x / 2.0, dimensions.y, -dimensions.z / 2.0)
	var c: Vector3 = p + Vector3(dimensions.x / 2.0, dimensions.y, dimensions.z / 2.0)
	var d: Vector3 = p + Vector3(-dimensions.x / 2.0, dimensions.y, dimensions.z / 2.0)
	var drop: Vector3 = Vector3(0, dimensions.y, 0)
	_poly([_point(d), _point(c), _point(c - drop), _point(d - drop)], color.darkened(0.08))
	_poly([_point(b), _point(c), _point(c - drop), _point(b - drop)], color.darkened(0.23))
	_poly([_point(a), _point(b), _point(c), _point(d)], color.lightened(0.10))

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)
