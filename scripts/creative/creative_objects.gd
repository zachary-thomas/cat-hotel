extends RefCounted
## Shared voxel parts are batched by material inside each independently editable item.
const SURFACE = preload("res://assets/shaders/voxel_surface.gdshader")
const WATER = preload("res://assets/shaders/water.gdshader")
const FONT = preload("res://assets/fonts/Fredoka.ttf")
const WaterMotion = preload("res://scripts/creative/creative_water_motion.gd")
static var _cube: BoxMesh
static var _materials: Dictionary = {}

static func box(parent: Node3D, point: Vector3, dimensions: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var parts: Dictionary = parent.get_meta("voxel_parts",{})
	var key: String = color.to_html()
	if not parts.has(key): parts[key] = []
	parts[key].append(Transform3D(Basis.from_euler(rotation).scaled(dimensions),point))
	parent.set_meta("voxel_parts",parts)

static func flush(parent: Node3D) -> void:
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	var parts: Dictionary = parent.get_meta("voxel_parts",{})
	for key in parts:
		if not _materials.has(key):
			var material = ShaderMaterial.new()
			material.shader = SURFACE
			material.set_shader_parameter("tint",Color(key))
			material.set_shader_parameter("grain",0.012)
			_materials[key] = material
		var mesh = MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_3D
		mesh.mesh = _cube
		mesh.instance_count = parts[key].size()
		for index in range(mesh.instance_count): mesh.set_instance_transform(index,parts[key][index])
		var instance = MultiMeshInstance3D.new()
		instance.multimesh = mesh
		instance.material_override = _materials[key]
		parent.add_child(instance)
	if parent.has_meta("voxel_parts"): parent.remove_meta("voxel_parts")
	for child in parent.get_children():
		if child is Node3D and not child is GeometryInstance3D: flush(child)

static func label(parent: Node3D, value: String, at: Vector3, size: float = 0.006, color: Color = Color("fff5de"), billboard: bool = false) -> Label3D:
	var text = Label3D.new()
	text.text = value
	text.font = FONT
	text.font_size = 48
	text.pixel_size = size
	text.position = at
	text.modulate = color
	text.outline_size = 0
	if billboard: text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(text)
	return text

static func make(definition: Dictionary) -> Node3D:
	var root = Node3D.new()
	var dims: Array = definition.get("size",[1,1])
	var w: float = maxf(0.32,float(dims[0])*1.1-0.08)
	var d: float = maxf(0.32,float(dims[1])*1.1-0.08)
	var c: Color = Color(String(definition.get("color","a5bc94")))
	var shape: String = String(definition.get("shape",definition.get("id","plant")))
	var wood: Color = Color("ae7953")
	var cream: Color = Color("f3e3c1")
	match shape:
		"mat", "sun_cushion", "heated", "blanket", "cave", "canopy_bed":
			_bed(root,w,d,c,shape)
		"cloud_sofa", "lounge_sofa", "bench":
			_legs(root,w,d,0.37,wood)
			box(root,Vector3(0,0.47,0),Vector3(w,0.22,d*0.88),c)
			box(root,Vector3(0,0.81,-d*0.37),Vector3(w,0.55,d*0.20),c.darkened(0.12))
			for side in [-1,1]:
				box(root,Vector3(side*w*0.43,0.63,0),Vector3(w*0.13,0.38,d),wood if shape=="bench" else c.darkened(0.06))
				if shape!="bench": box(root,Vector3(side*w*0.26,0.66,-d*0.10),Vector3(w*0.22,0.30,d*0.25),cream if side==1 else Color("dfa697"))
			if shape=="bench":
				for plank in range(4):
					box(root,Vector3(0,0.590,(float(plank)-1.5)*d*0.17),Vector3(w*0.77,0.025,d*0.14),c.lightened(0.055 if plank%2 else 0.0))
				for plank in range(3):
					box(root,Vector3(0,0.69+float(plank)*0.145,-d*0.26),Vector3(w*0.78,0.12,0.028),c.lightened(0.09))
				for side in [-1,1]: box(root,Vector3(side*w*0.43,0.855,0),Vector3(w*0.16,0.07,d*0.91),c.lightened(0.13))
		"perch":
			_legs(root,w,d,0.72,wood)
			box(root,Vector3(0,0.84,0),Vector3(w,0.17,d),wood)
			box(root,Vector3(0,0.96,0),Vector3(w*0.9,0.16,d*0.85),c)
			box(root,Vector3(w*0.27,1.1,-d*0.18),Vector3(w*0.28,0.23,d*0.32),cream)
			for seam in [-0.25,0,0.25]: box(root,Vector3(seam*w,1.045,d*0.08),Vector3(0.016,0.014,d*0.50),c.lightened(0.20))
			box(root,Vector3(0,0.36,0),Vector3(w*0.78,0.10,d*0.62),wood)
			for book in range(4): box(root,Vector3((-0.22+float(book)*0.14)*w,0.50,0),Vector3(w*0.10,0.19+float(book%2)*0.06,d*0.35),[c,Color("d49a88"),cream,Color("90a573")][book])
		"cafe_stool":
			_legs(root,w*0.8,d*0.8,0.66,wood)
			box(root,Vector3(0,0.70,0),Vector3(w,0.15,d),c)
			box(root,Vector3(0,0.82,-d*0.41),Vector3(w*0.9,0.25,0.10),c.darkened(0.16))
		"picnic":
			_picnic(root,w,d,c)
		"table", "cafe_table":
			_legs(root,w*0.75,d*0.75,0.68,wood)
			box(root,Vector3(0,0.79,0),Vector3(w,0.14,d),c)
			if shape=="table":
				for side in [-1,1]:
					box(root,Vector3(0,0.43,side*d*0.41),Vector3(w,0.14,d*0.18),wood)
					for x in [-0.3,0.3]: box(root,Vector3(x*w,0.2,side*d*0.4),Vector3(0.12,0.4,0.12),wood)
			else:
				box(root,Vector3(0,0.91,0),Vector3(w*0.2,0.16,d*0.2),Color("e0b894"))
				box(root,Vector3(0,1.09,0),Vector3(w*0.29,0.22,d*0.26),Color("6d956a"))
		"milkshake_counter", "reception_counter":
			box(root,Vector3(0,0.56,0),Vector3(w*0.95,1.07,d*0.82),c)
			box(root,Vector3(0,1.14,0),Vector3(w,0.16,d),cream)
			for index in range(8):
				var x: float = -w*0.43+float(index)*w*0.123
				box(root,Vector3(x,0.49,d*0.422),Vector3(w*0.035,0.68,0.035),c.lightened(0.18))
			box(root,Vector3(0,0.95,d*0.44),Vector3(w*0.66,0.19,0.035),wood)
			if shape=="milkshake_counter": label(root,"MILKSHAKES",Vector3(0,0.97,d*0.465),minf(0.0037,w/145.0),cream)
			if shape=="milkshake_counter":
				for x in [-0.27,0,0.27]: drink(root,Vector3(x*w,1.24,d*0.17),Color("e9a7aa") if x<0 else Color("edcc92"))
				box(root,Vector3(-w*0.31,1.49,-d*0.21),Vector3(w*0.20,0.46,d*0.34),Color("d4e0d4"))
				box(root,Vector3(-w*0.31,1.64,-d*0.03),Vector3(w*0.14,0.21,0.03),Color("6e9088"))
				box(root,Vector3(w*0.23,1.54,-d*0.24),Vector3(w*0.31,0.64,0.06),wood)
				label(root,"SHAKE\n& PURR",Vector3(w*0.23,1.57,-d*0.198),minf(0.0033,w/220.0),cream)
			else:
				box(root,Vector3(w*0.25,1.37,0),Vector3(w*0.24,0.34,d*0.30),Color("6b8174"))
				box(root,Vector3(w*0.25,1.40,d*0.162),Vector3(w*0.19,0.22,0.035),Color("bbd9c9"))
				box(root,Vector3(-w*0.24,1.30,d*0.08),Vector3(0.20,0.17,0.20),Color("d9b65b"))
				# A framed front plaque, ledger, bell and amber desk lantern.
				box(root,Vector3(0,0.56,d*0.438),Vector3(w*0.63,0.56,0.05),wood)
				box(root,Vector3(0,0.56,d*0.475),Vector3(w*0.58,0.45,0.034),cream)
				label(root,"PURRINGTON\nHOTEL",Vector3(0,0.56,d*0.496),0.0038,Color("876d4e"))
				for side in [-1,1]: box(root,Vector3(side*w*0.45,0.56,d*0.434),Vector3(0.10,1.04,0.06),wood)
				box(root,Vector3(-w*0.10,1.25,d*0.10),Vector3(w*0.19,0.045,d*0.33),Color("9b7660"))
				box(root,Vector3(-w*0.10,1.28,d*0.10),Vector3(w*0.17,0.016,d*0.29),cream)
				box(root,Vector3(-w*0.40,1.28,-d*0.14),Vector3(0.27,0.07,0.26),wood)
				box(root,Vector3(-w*0.40,1.48,-d*0.14),Vector3(0.075,0.36,0.075),Color("d2a55f"))
				box(root,Vector3(-w*0.40,1.73,-d*0.14),Vector3(0.35,0.24,0.34),Color("f4d48b"))
				box(root,Vector3(-w*0.40,1.87,-d*0.14),Vector3(0.30,0.055,0.29),cream)
		"fireplace":
			box(root,Vector3(0,0.65,0),Vector3(w*0.91,1.30,d*0.90),c)
			box(root,Vector3(0,0.47,d*0.46),Vector3(w*0.62,0.66,0.04),Color("655953"))
			box(root,Vector3(0,1.3,0),Vector3(w,0.17,d),cream)
			for x in [-0.18,0.06,0.23]:
				box(root,Vector3(x*w,0.28,d*0.5),Vector3(w*0.14,0.30+absf(x),0.09),Color("f2be67"))
		"plant", "garden_planter", "shrub", "flowers", "flower_bed":
			_planter(root,w,d,c,shape)
		"lamp", "garden_lamp":
			box(root,Vector3(0,0.13,0),Vector3(w*0.70,0.24,d*0.7),wood)
			box(root,Vector3(0,0.85,0),Vector3(0.11,1.45,0.11),wood)
			box(root,Vector3(0,1.54,0),Vector3(w*0.64,0.46,d*0.64),Color("f3d893"))
			box(root,Vector3(0,1.83,0),Vector3(w*0.81,0.13,d*0.81),c)
			box(root,Vector3(0,1.30,0),Vector3(w*0.75,0.10,d*0.75),c)
		"box":
			box(root,Vector3(0,0.06,0),Vector3(w,0.12,d),c)
			for side in [-1,1]:
				box(root,Vector3(side*w*0.45,0.37,0),Vector3(w*0.1,0.72,d),c)
				box(root,Vector3(0,0.37,side*d*0.45),Vector3(w,0.72,d*0.1),c)
			box(root,Vector3(0,0.80,-d*0.54),Vector3(w,0.08,d*0.4),c.lightened(0.12),Vector3(-0.35,0,0))
		"tunnel":
			box(root,Vector3(0,0.05,0),Vector3(w,0.1,d),c)
			for side in [-1,1]: box(root,Vector3(0,0.39,side*d*0.43),Vector3(w,0.72,d*0.14),c)
			box(root,Vector3(0,0.80,0),Vector3(w,0.16,d),c.lightened(0.13))
		"tower", "adventure_tree", "scratch":
			box(root,Vector3(0,0.09,0),Vector3(w,0.18,d),wood)
			var high: float = 1.0 if shape=="scratch" else 1.7
			box(root,Vector3(0,high*0.5,0),Vector3(w*0.20,high,d*0.23),cream)
			for rung in range(6): box(root,Vector3(0,0.25+float(rung)*high/7.0,0),Vector3(w*0.23,0.055,d*0.26),Color("c1a17a"))
			box(root,Vector3(0,high,0),Vector3(w*0.85,0.13,d*0.85),c)
			if shape=="adventure_tree":
				box(root,Vector3(w*0.30,0.58,d*0.22),Vector3(w*0.58,0.82,d*0.59),c)
				box(root,Vector3(w*0.30,0.52,d*0.52),Vector3(w*0.27,0.39,0.025),Color("5d6656"))
		"rug":
			box(root,Vector3(0,0.035,0),Vector3(w,0.05,d),c)
			box(root,Vector3(0,0.064,0),Vector3(w*0.77,0.008,d*0.77),c.lightened(0.16))
			paw(root,Vector3(0,0.077,0),minf(w,d)*0.48,cream)
			for side in [-1,1]:
				for fringe in range(12): box(root,Vector3((float(fringe)/11.0-0.5)*w*0.94,0.028,side*d*0.505),Vector3(0.034,0.025,0.09),cream)
		"pool", "fountain":
			_fountain(root,w,d,c,shape=="fountain")
		"fence", "gate":
			for side in [-1,1]: box(root,Vector3(side*w*0.44,0.62,0),Vector3(0.13,1.20,d*0.5),c)
			if shape=="gate":
				for side in [-1,1]:
					var leaf = Node3D.new()
					root.add_child(leaf)
					leaf.position.x = float(side)*w*0.44
					leaf.rotation.y = float(side)*1.18
					for y in [0.36,0.86]: box(leaf,Vector3(-float(side)*w*0.22,y,0),Vector3(w*0.45,0.11,d*0.25),c)
					box(leaf,Vector3(-float(side)*w*0.24,0.60,0),Vector3(w*0.49,0.07,d*0.21),c.lightened(0.10),Vector3(0,0,float(side)*0.44))
			else:
				for y in [0.36,0.86]: box(root,Vector3(0,y,0),Vector3(w,0.12,d*0.36),c)
				for x in [-0.3,-0.1,0.1,0.3]: box(root,Vector3(x*w,0.66,0),Vector3(0.07,0.91,d*0.29),c)
		"tree": _tree(root,minf(w,d)*1.2,c,false,false)
		"cat_statue":
			box(root,Vector3(0,0.14,0),Vector3(w,0.28,d),wood)
			box(root,Vector3(0,0.56,0),Vector3(w*0.51,0.64,d*0.58),c)
			box(root,Vector3(0,1.07,d*0.12),Vector3(w*0.61,0.47,d*0.45),c)
			for side in [-1,1]: box(root,Vector3(side*w*0.22,1.38,d*0.10),Vector3(w*0.17,0.22,d*0.18),c)
		"litter":
			box(root,Vector3(0,0.20,0),Vector3(w,0.4,d),c)
			box(root,Vector3(0,0.41,0),Vector3(w*0.82,0.04,d*0.82),cream)
			box(root,Vector3(0,0.68,-d*0.40),Vector3(w,0.52,d*0.16),c)
		"playpen":
			box(root,Vector3(0,0.06,0),Vector3(w,0.12,d),cream)
			for side in [-1,1]:
				for i in range(6):
					box(root,Vector3(side*w*0.46,0.43,(-0.43+float(i)*0.17)*d),Vector3(0.06,0.76,0.06),c)
				box(root,Vector3(side*w*0.46,0.82,0),Vector3(0.09,0.09,d),c)
			box(root,Vector3(0.1,0.27,0),Vector3(0.3,0.3,0.3),Color("dc9d86"))
		_:
			box(root,Vector3(0,0.23,0),Vector3(w,0.45,d),c)
	root.set_meta("shape",shape)
	root.set_meta("footprint",Vector2(w,d))
	flush(root)
	return root

static func _legs(root: Node3D, w: float, d: float, height: float, color: Color) -> void:
	for x in [-1,1]:
		for z in [-1,1]: box(root,Vector3(x*w*0.36,height*0.5,z*d*0.34),Vector3(0.10,height,0.10),color)

static func _bed(root: Node3D, w: float, d: float, color: Color, shape: String) -> void:
	var wood: Color = Color("b58259")
	var linen: Color = Color("f8eaca")
	_legs(root,w,d,0.18,wood.darkened(0.16))
	box(root,Vector3(0,0.19,0),Vector3(w,0.19,d),wood)
	# Stepped edge and piping give the cushion volume while retaining cube faces.
	box(root,Vector3(0,0.29,0),Vector3(w*0.96,0.10,d*0.95),linen)
	box(root,Vector3(0,0.40,0),Vector3(w*0.89,0.20,d*0.88),color)
	box(root,Vector3(0,0.50,0),Vector3(w*0.80,0.07,d*0.79),color.lightened(0.045))
	var cols: int = 6
	var rows: int = 7
	for x in range(cols):
		for z in range(rows):
			var patch: Color = color
			if shape=="blanket":
				patch = [color,linen,color.lightened(0.18),Color("a9bba6")][posmod(x+z*2,4)]
			elif (x+z)%2==0: patch = color.lightened(0.26)
			box(root,Vector3((float(x)+0.5)/cols*w*0.79-w*0.395,0.540,(float(z)+0.5)/rows*d*0.76-d*0.38),Vector3(w*0.79/cols-0.012,0.022,d*0.76/rows-0.012),patch)
	for side in [-1,1]:
		for stitch in range(8):
			box(root,Vector3(side*w*0.448,0.42,(float(stitch)/7.0-0.5)*d*0.72),Vector3(0.012,0.075,0.023),linen.darkened(0.06))
	box(root,Vector3(0,0.55,-d*0.31),Vector3(w*0.70,0.19,d*0.23),linen)
	box(root,Vector3(0,0.65,-d*0.31),Vector3(w*0.60,0.045,d*0.18),linen.lightened(0.10))
	paw(root,Vector3(w*0.19,0.678,-d*0.31),0.18,color)
	if shape in ["mat","sun_cushion","heated","canopy_bed"]:
		box(root,Vector3(0,0.59,-d*0.46),Vector3(w*0.98,0.68,0.12),wood)
		box(root,Vector3(0,0.83,-d*0.39),Vector3(w*0.84,0.32,0.11),linen)
		for button in [-1,1]: box(root,Vector3(button*w*0.22,0.84,-d*0.328),Vector3(0.07,0.07,0.025),color)
		box(root,Vector3(0,0.96,-d*0.46),Vector3(w,0.08,0.17),wood.lightened(0.12))
	if shape=="cave":
		for side in [-1,1]: box(root,Vector3(side*w*0.43,0.87,-d*0.12),Vector3(w*0.15,0.80,d*0.70),color.darkened(0.10))
		box(root,Vector3(0,1.30,-d*0.13),Vector3(w*0.88,0.16,d*0.73),color)
		box(root,Vector3(0,1.41,-d*0.13),Vector3(w*0.66,0.10,d*0.65),color.lightened(0.13))
		box(root,Vector3(0,0.92,-d*0.45),Vector3(w*0.91,0.8,d*0.12),color)
	if shape=="canopy_bed":
		for x in [-1,1]:
			for z in [-1,1]:
				box(root,Vector3(x*w*0.43,1.06,z*d*0.43),Vector3(0.09,2.02,0.09),wood)
				box(root,Vector3(x*w*0.43,2.10,z*d*0.43),Vector3(0.14,0.14,0.14),linen)
		box(root,Vector3(0,2.06,0),Vector3(w*0.98,0.10,d*0.98),linen)
		for side in [-1,1]: box(root,Vector3(side*w*0.40,1.89,-d*0.30),Vector3(w*0.12,0.33,d*0.23),color)
	if shape=="heated":
		box(root,Vector3(w*0.51,0.24,d*0.15),Vector3(0.08,0.19,0.17),linen)
		box(root,Vector3(w*0.553,0.28,d*0.15),Vector3(0.016,0.04,0.04),Color("eaa655"))

static func paw(root: Node3D, at: Vector3, size: float, color: Color) -> void:
	box(root,at+Vector3(0,0,size*0.19),Vector3(size*0.62,0.016,size*0.49),color)
	box(root,at+Vector3(0,0,size*0.08),Vector3(size*0.78,0.016,size*0.22),color)
	for toe in range(4):
		box(root,at+Vector3((float(toe)-1.5)*size*0.28,0,-size*(0.26 if toe in [1,2] else 0.10)),Vector3(size*0.20,0.016,size*0.25),color)

static func _foliage(root: Node3D, at: Vector3, dimensions: Vector3, color: Color) -> void:
	# A filled stepped crown, then small offset leaf clusters break the silhouette.
	for layer in range(3):
		var breadth: float = 0.72 if layer!=1 else 1.0
		box(root,at+Vector3(0,(float(layer)-1)*dimensions.y*0.27,0),Vector3(dimensions.x*breadth,dimensions.y*0.42,dimensions.z*breadth),color.lightened(float(layer)*0.035))
	for i in range(12):
		var x: float = (float(i%4)/3.0-0.5)*dimensions.x*0.88
		var z: float = (float(i/4)/2.0-0.5)*dimensions.z*0.91
		var y: float = dimensions.y*(0.19+float((i*3)%5)*0.07)
		box(root,at+Vector3(x,y,z),Vector3(dimensions.x*0.28,dimensions.y*0.30,dimensions.z*0.29),color.lightened(float(i%3)*0.055))

static func _flower(root: Node3D, at: Vector3, height: float, color: Color) -> void:
	var stem: Color = Color("548651")
	box(root,at+Vector3(0,height*0.5,0),Vector3(height*0.09,height,height*0.09),stem)
	for side in [-1,1]: box(root,at+Vector3(side*height*0.14,height*(0.38 if side==1 else 0.59),0),Vector3(height*0.29,height*0.10,height*0.18),stem.lightened(0.09))
	var top: Vector3 = at+Vector3(0,height,0)
	box(root,top,Vector3(height*0.42,height*0.12,height*0.18),color)
	box(root,top,Vector3(height*0.18,height*0.12,height*0.42),color)
	box(root,top+Vector3(0,height*0.072,0),Vector3(height*0.15,height*0.055,height*0.15),Color("f7d880"))

static func _planter(root: Node3D, w: float, d: float, color: Color, shape: String) -> void:
	var pot: Color = Color("c88d70")
	if shape in ["garden_planter","flower_bed"]: pot = Color("ae8058")
	var height: float = 0.29 if shape=="flower_bed" else 0.36
	box(root,Vector3(0,height*0.43,0),Vector3(w*0.75,height*0.85,d*0.75),pot)
	box(root,Vector3(0,height*0.87,0),Vector3(w*0.88,height*0.21,d*0.88),pot.lightened(0.16))
	box(root,Vector3(0,height*0.99,0),Vector3(w*0.71,0.026,d*0.71),Color("75644e"))
	if shape in ["garden_planter","flower_bed"]:
		for side in [-1,1]:
			for band in [0.27,0.64]: box(root,Vector3(0,height*band,side*d*0.386),Vector3(w*0.79,0.034,0.025),pot.darkened(0.14))
	if shape in ["plant","garden_planter"]:
		for leaf in range(7):
			var angle: float = float(leaf)*TAU/7.0
			var at: Vector3 = Vector3(cos(angle)*w*0.21,height+0.10+float(leaf%3)*0.10,sin(angle)*d*0.19)
			box(root,Vector3(0,height+0.23,0),Vector3(0.045,0.49,0.045),Color("628453"))
			_foliage(root,at,Vector3(w*0.43,0.30+float(leaf%2)*0.14,d*0.36),Color("71a268").lightened(float(leaf%3)*0.055))
	elif shape=="shrub":
		_foliage(root,Vector3(0,height+0.33,0),Vector3(w*0.97,0.69,d*0.96),color)
	else:
		var count: int = 10 if shape=="flower_bed" else 4
		for i in range(count):
			var x: float = (float(i%5)/4.0-0.5)*w*0.66 if count>4 else (float(i%2)-0.5)*w*0.43
			var z: float = (float(i/5)-0.5)*d*0.44 if count>4 else (float(i/2)-0.5)*d*0.43
			_flower(root,Vector3(x,height,z),0.30+float(i%3)*0.065,color.lightened(float(i%2)*0.12))

static func _picnic(root: Node3D, w: float, d: float, color: Color) -> void:
	var cream: Color = Color("f5e6c6")
	box(root,Vector3(0,0.045,0),Vector3(w*0.95,0.075,d*0.95),cream)
	for x in range(8):
		for z in range(8):
			var square: Color = cream if (x+z)%2==0 else color
			if x%2==0 and z%2==0: square = color.lightened(0.25)
			box(root,Vector3((float(x)+0.5)/8.0*w*0.93-w*0.465,0.093,(float(z)+0.5)/8.0*d*0.93-d*0.465),Vector3(w*0.93/8.0-0.01,0.025,d*0.93/8.0-0.01),square)
	for x in [-1,1]:
		for z in [-1,1]:
			var at: Vector3 = Vector3(x*w*0.32,0.17,z*d*0.32)
			box(root,at,Vector3(w*0.24,0.13,d*0.24),Color("eac47a"))
			box(root,at+Vector3(0,0.075,0),Vector3(w*0.20,0.04,d*0.20),Color("f0d699"))
			paw(root,at+Vector3(0,0.102,0),0.25,cream)
	var basket: Color = Color("c39a68")
	box(root,Vector3(0,0.28,-d*0.035),Vector3(w*0.23,0.36,d*0.19),basket)
	box(root,Vector3(0,0.47,-d*0.035),Vector3(w*0.25,0.065,d*0.21),basket.lightened(0.17))
	for side in [-1,1]:
		for stripe in range(4): box(root,Vector3(0,0.17+float(stripe)*0.085,-d*0.035+side*d*0.098),Vector3(w*0.24,0.025,0.02),basket.darkened(0.16))
		box(root,Vector3(side*w*0.085,0.66,-d*0.035),Vector3(0.075,0.36,0.075),basket)
	box(root,Vector3(0,0.85,-d*0.035),Vector3(w*0.19,0.08,0.08),basket)
	box(root,Vector3(w*0.16,0.12,d*0.12),Vector3(0.43,0.045,0.36),cream)
	for fruit in range(3): box(root,Vector3(w*0.16+float(fruit%2)*0.13-0.06,0.20,d*0.12+float(fruit/2)*0.13-0.05),Vector3(0.12,0.11,0.12),Color("d99773") if fruit<2 else Color("94ae68"))
	drink(root,Vector3(-w*0.17,0.11,d*0.10),Color("e4b195"))
	for side in [-1,1]:
		for fringe in range(12): box(root,Vector3((float(fringe)/11.0-0.5)*w*0.89,0.036,side*d*0.48),Vector3(0.033,0.032,0.10),cream)

static func _fountain(root: Node3D, w: float, d: float, color: Color, tiered: bool) -> void:
	var stone: Color = Color("d8ceb4")
	box(root,Vector3(0,0.09,0),Vector3(w,0.18,d),stone.darkened(0.13))
	box(root,Vector3(0,0.22,0),Vector3(w*0.94,0.21,d*0.94),color.darkened(0.10))
	water(root,Vector3(0,0.345,0),Vector2(w*0.79,d*0.79),Color("63b7bc"))
	for side in [-1,1]:
		box(root,Vector3(side*w*0.45,0.36,0),Vector3(w*0.1,0.23,d),stone)
		box(root,Vector3(0,0.36,side*d*0.45),Vector3(w*0.80,0.23,d*0.1),stone)
		for tile in range(7):
			box(root,Vector3((float(tile)/6.0-0.5)*w*0.90,0.483,side*d*0.45),Vector3(w*0.116,0.025,d*0.10),stone.lightened(0.08 if tile%2 else 0.0))
	if not tiered: return
	box(root,Vector3(0,0.64,0),Vector3(w*0.19,0.65,d*0.19),stone)
	box(root,Vector3(0,0.85,0),Vector3(w*0.34,0.15,d*0.34),stone.darkened(0.05))
	box(root,Vector3(0,1.00,0),Vector3(w*0.52,0.15,d*0.52),stone)
	box(root,Vector3(0,1.12,0),Vector3(w*0.67,0.12,d*0.67),stone.lightened(0.05))
	water(root,Vector3(0,1.20,0),Vector2(w*0.60,d*0.60),Color("81ced0"))
	box(root,Vector3(0,1.45,0),Vector3(w*0.12,0.55,d*0.12),stone)
	box(root,Vector3(0,1.74,0),Vector3(w*0.22,0.13,d*0.22),stone)
	box(root,Vector3(0,1.82,0),Vector3(w*0.34,0.10,d*0.34),stone.lightened(0.08))
	water(root,Vector3(0,1.88,0),Vector2(w*0.30,d*0.30),Color("9bded8"))
	box(root,Vector3(0,2.00,0),Vector3(0.10,0.22,0.10),Color("a6e4dc"))
	var falling = WaterMotion.new()
	falling.name = "VoxelSpillways"
	root.add_child(falling)
	falling.build(w,d)

static func drink(root: Node3D, at: Vector3, color: Color) -> void:
	box(root,at+Vector3(0,0.16,0),Vector3(0.18,0.30,0.18),color)
	box(root,at+Vector3(0,0.33,0),Vector3(0.22,0.07,0.22),Color("fff1d7"))
	box(root,at+Vector3(0.045,0.48,0),Vector3(0.025,0.28,0.025),Color("c06c79"),Vector3(0,0,-0.19))
	box(root,at+Vector3(-0.03,0.39,0),Vector3(0.065,0.065,0.065),Color("d57b78"))

static func water(root: Node3D, at: Vector3, dimensions: Vector2, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	var volume = BoxMesh.new()
	volume.size = Vector3(dimensions.x,0.035,dimensions.y)
	mesh.mesh = volume
	mesh.position = at
	var material = ShaderMaterial.new()
	material.shader = WATER
	material.set_shader_parameter("deep_color",color)
	material.set_shader_parameter("shore_z",-1000.0)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)

static func _tree(root: Node3D, scale_value: float, color: Color, pine: bool, snowy: bool) -> void:
	box(root,Vector3(0,scale_value*0.68,0),Vector3(scale_value*0.17,scale_value*1.35,scale_value*0.17),Color("9e7456"))
	if pine:
		for level in range(4):
			var breadth: float = scale_value*(1.23-float(level)*0.23)
			box(root,Vector3(0,scale_value*(0.83+float(level)*0.36),0),Vector3(breadth,scale_value*0.49,breadth),color.lightened(float(level)*0.035))
			if snowy: box(root,Vector3(0,scale_value*(1.075+float(level)*0.36),0),Vector3(breadth*1.01,0.10,breadth*1.01),Color("f1f0df"))
	else:
		for branch in [-1,1]:
			box(root,Vector3(branch*scale_value*0.19,scale_value*1.10,0),Vector3(scale_value*0.45,scale_value*0.14,scale_value*0.13),Color("9e7456"))
		_foliage(root,Vector3(0,scale_value*1.47,0),Vector3(scale_value*1.42,scale_value*1.0,scale_value*1.33),color)
		_foliage(root,Vector3(-scale_value*0.26,scale_value*1.97,scale_value*0.03),Vector3(scale_value*0.82,scale_value*0.65,scale_value*0.88),color.lightened(0.05))

static func scenery(kind: String, size: float, color: Color, snowy: bool = false) -> Node3D:
	var root = Node3D.new()
	match kind:
		"tree", "pine": _tree(root,size,color,kind=="pine",snowy)
		"palm":
			box(root,Vector3(0,size*0.85,0),Vector3(size*0.18,size*1.7,size*0.18),Color("b19168"),Vector3(0,0,-0.10))
			for angle in range(6):
				var branch = Node3D.new()
				root.add_child(branch)
				branch.rotation.y = float(angle)*PI/3.0+0.3
				box(branch,Vector3(size*0.27,size*1.84,0),Vector3(size*0.65,size*0.13,size*0.29),color,Vector3(0,0,0.16))
				box(branch,Vector3(size*0.69,size*1.71,0),Vector3(size*0.51,size*0.11,size*0.23),color.lightened(0.025),Vector3(0,0,-0.55))
				box(branch,Vector3(size*0.91,size*1.48,0),Vector3(size*0.29,size*0.09,size*0.11),color,Vector3(0,0,-0.83))
			for side in [-1,1]: box(root,Vector3(side*size*0.12,size*1.61,0),Vector3(size*0.16,size*0.18,size*0.16),Color("ac8961"))
		"shrub":
			_foliage(root,Vector3(0,size*0.42,0),Vector3(size*1.2,size*0.83,size),color)
		"snowdrift", "dune", "rock":
			box(root,Vector3(0,size*0.27,0),Vector3(size*1.20,size*0.54,size*0.88),color)
			box(root,Vector3(-size*0.13,size*0.61,-size*0.10),Vector3(size*0.73,size*0.19,size*0.65),color.lightened(0.07))
		"pond", "frozen_pond", "sea":
			for level in range(3):
				var breadth: float = size*(0.65 if level!=1 else 1.12)
				box(root,Vector3(0,0.015,float(level-1)*size*0.25),Vector3(breadth+0.13,0.07,size*0.27),Color("d4cfa6") if not snowy else Color("e5e9da"))
				water(root,Vector3(0,0.065+float(level)*0.0003,float(level-1)*size*0.25),Vector2(breadth,size*0.26),color)
			if kind=="frozen_pond":
				for i in range(3): box(root,Vector3(-size*0.24+float(i)*size*0.18,0.07,float(i%2)*size*0.17),Vector3(size*0.20,0.015,0.04),Color("e3f0e9"),Vector3(0,float(i)*0.7,0))
		"stream":
			for segment in range(5):
				var x: float = float(segment-2)*size*0.80
				var z: float = float(segment%2)*size*0.15
				box(root,Vector3(x,0.012,z),Vector3(size*0.87,0.06,size*0.56),Color("bcc5a0"))
				water(root,Vector3(x,0.06+float(segment)*0.0003,z),Vector2(size*0.84,size*0.50),color)
		"mountain":
			for level in range(6):
				var breadth: float = size*(1.5-float(level)*0.20)
				box(root,Vector3(0,size*(0.12+float(level)*0.22),0),Vector3(breadth,size*0.28,breadth*0.78),color if level<4 else Color("edeede"))
		"log":
			box(root,Vector3(0,0.31,0),Vector3(size*1.4,0.57,size*0.38),Color("8f7055"))
			for side in [-1,1]: box(root,Vector3(side*size*0.706,0.31,0),Vector3(0.02,0.42,size*0.27),Color("c5a575"))
		"flowers", "mushroom":
			for i in range(7):
				var x: float = (float(i%3)-1.0)*size*0.32
				var z: float = (float(i/3)-0.6)*size*0.35
				if kind=="flowers":
					_flower(root,Vector3(x,0,z),size*(0.37+float(i%3)*0.07),color.lightened(float(i%2)*0.10))
				else:
					box(root,Vector3(x,size*0.22,z),Vector3(size*0.08,size*0.43,size*0.08),Color("b4b58c"))
					box(root,Vector3(x,size*0.43,z),Vector3(size*0.27,size*0.16,size*0.26),color)
		"boat":
			box(root,Vector3(0,0.25,0),Vector3(size*1.1,0.35,size*0.51),color)
			box(root,Vector3(0,size*0.72,0),Vector3(0.08,size*1.4,0.08),Color("af8d62"))
			box(root,Vector3(size*0.26,size*0.91,0),Vector3(size*0.52,size*0.60,0.04),Color("f5e7c6"))
		"buoy":
			box(root,Vector3(0,0.35,0),Vector3(size*0.45,0.6,size*0.45),color)
			box(root,Vector3(0,0.62,0),Vector3(size*0.45,0.15,size*0.45),Color("f2edda"))
		"house":
			box(root,Vector3(0,size*0.5,0),Vector3(size*1.1,size,size*0.90),Color("e1c6a0"))
			for level in range(4): box(root,Vector3(0,size*(1.04+float(level)*0.14),0),Vector3(size*(1.28-float(level)*0.27),size*0.17,size*1.07),color)
			for side in [-1,1]: box(root,Vector3(side*size*0.29,size*0.59,size*0.46),Vector3(size*0.20,size*0.29,0.035),Color("83a8a2"))
	flush(root)
	return root
