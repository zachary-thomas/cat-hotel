extends RefCounted
## Shared voxel parts are batched by material inside each independently editable item.
const SURFACE = preload("res://assets/shaders/voxel_surface.gdshader")
const WATER = preload("res://assets/shaders/water.gdshader")
const FONT = preload("res://assets/fonts/Fredoka.ttf")
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
			box(root,Vector3(0,0.13,0),Vector3(w,0.22,d),wood)
			box(root,Vector3(0,0.28,0),Vector3(w*0.9,0.20,d*0.89),c)
			box(root,Vector3(0,0.42,-d*0.26),Vector3(w*0.66,0.18,d*0.28),cream)
			if shape=="cave":
				for side in [-1,1]: box(root,Vector3(side*w*0.43,0.63,-d*0.12),Vector3(w*0.14,0.68,d*0.75),c.darkened(0.12))
				box(root,Vector3(0,0.99,-d*0.13),Vector3(w,0.17,d*0.76),c)
				box(root,Vector3(0,0.63,-d*0.44),Vector3(w,0.66,d*0.12),c)
			if shape=="canopy_bed":
				for x in [-1,1]:
					for z in [-1,1]: box(root,Vector3(x*w*0.43,1.0,z*d*0.42),Vector3(0.09,1.9,0.09),wood)
				box(root,Vector3(0,1.94,0),Vector3(w*1.01,0.15,d*1.01),cream)
			if shape=="heated":
				for x in [-0.3,0,0.3]: box(root,Vector3(x*w,0.395,d*0.15),Vector3(0.07,0.02,d*0.4),Color("edb66c"))
		"cloud_sofa", "lounge_sofa", "bench":
			_legs(root,w,d,0.37,wood)
			box(root,Vector3(0,0.47,0),Vector3(w,0.22,d*0.88),c)
			box(root,Vector3(0,0.81,-d*0.37),Vector3(w,0.55,d*0.20),c.darkened(0.12))
			for side in [-1,1]:
				box(root,Vector3(side*w*0.43,0.63,0),Vector3(w*0.13,0.38,d),wood if shape=="bench" else c.darkened(0.06))
				if shape!="bench": box(root,Vector3(side*w*0.26,0.66,-d*0.10),Vector3(w*0.22,0.30,d*0.25),cream if side==1 else Color("dfa697"))
		"perch":
			_legs(root,w,d,0.72,wood)
			box(root,Vector3(0,0.84,0),Vector3(w,0.17,d),wood)
			box(root,Vector3(0,0.96,0),Vector3(w*0.9,0.16,d*0.85),c)
			box(root,Vector3(w*0.27,1.1,-d*0.18),Vector3(w*0.28,0.23,d*0.32),cream)
		"cafe_stool":
			_legs(root,w*0.8,d*0.8,0.66,wood)
			box(root,Vector3(0,0.70,0),Vector3(w,0.15,d),c)
			box(root,Vector3(0,0.82,-d*0.41),Vector3(w*0.9,0.25,0.10),c.darkened(0.16))
		"table", "picnic", "cafe_table":
			_legs(root,w*0.75,d*0.75,0.68,wood)
			box(root,Vector3(0,0.79,0),Vector3(w,0.14,d),c)
			if shape in ["table","picnic"]:
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
			label(root,"MILKSHAKES" if shape=="milkshake_counter" else "WELCOME",Vector3(0,0.97,d*0.465),minf(0.0037,w/145.0),cream)
			if shape=="milkshake_counter":
				for x in [-0.27,0,0.27]: drink(root,Vector3(x*w,1.24,d*0.17),Color("e9a7aa") if x<0 else Color("edcc92"))
				box(root,Vector3(-w*0.31,1.49,-d*0.21),Vector3(w*0.20,0.46,d*0.34),Color("d4e0d4"))
				box(root,Vector3(-w*0.31,1.64,-d*0.03),Vector3(w*0.14,0.21,0.03),Color("6e9088"))
				box(root,Vector3(w*0.23,1.54,-d*0.24),Vector3(w*0.31,0.64,0.06),wood)
				label(root,"SHAKE\n& PURR",Vector3(w*0.23,1.57,-d*0.198),minf(0.0033,w/220.0),cream)
			else:
				box(root,Vector3(w*0.25,1.37,0),Vector3(w*0.24,0.34,d*0.30),Color("6b8174"))
				box(root,Vector3(-w*0.24,1.30,d*0.08),Vector3(0.20,0.17,0.20),Color("d9b65b"))
		"fireplace":
			box(root,Vector3(0,0.65,0),Vector3(w*0.91,1.30,d*0.90),c)
			box(root,Vector3(0,0.47,d*0.46),Vector3(w*0.62,0.66,0.04),Color("655953"))
			box(root,Vector3(0,1.3,0),Vector3(w,0.17,d),cream)
			for x in [-0.18,0.06,0.23]:
				box(root,Vector3(x*w,0.28,d*0.5),Vector3(w*0.14,0.30+absf(x),0.09),Color("f2be67"))
		"plant", "garden_planter", "shrub", "flowers", "flower_bed":
			box(root,Vector3(0,0.18,0),Vector3(w*0.8,0.36,d*0.8),wood if shape=="garden_planter" else Color("d3a387"))
			for x in [-0.25,0.18]:
				box(root,Vector3(x*w,0.58,0),Vector3(w*0.49,0.45,d*0.66),c if shape in ["plant","shrub"] else Color("779668"))
				if shape in ["flowers","flower_bed"]:
					for z in [-0.22,0.22]: box(root,Vector3(x*w,0.84,z*d),Vector3(w*0.23,0.18,d*0.24),c)
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
		"pool", "fountain":
			box(root,Vector3(0,0.16,0),Vector3(w,0.32,d),c)
			water(root,Vector3(0,0.335,0),Vector2(w*0.80,d*0.80),Color("75b7b4"))
			if shape=="fountain":
				box(root,Vector3(0,0.80,0),Vector3(w*0.15,1.0,d*0.15),Color("d3cfb3"))
				box(root,Vector3(0,1.34,0),Vector3(w*0.45,0.16,d*0.45),cream)
				box(root,Vector3(0,1.50,0),Vector3(0.18,0.28,0.18),Color("99d6d0"))
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

static func drink(root: Node3D, at: Vector3, color: Color) -> void:
	box(root,at+Vector3(0,0.16,0),Vector3(0.18,0.30,0.18),color)
	box(root,at+Vector3(0,0.33,0),Vector3(0.22,0.07,0.22),Color("fff1d7"))
	box(root,at+Vector3(0.045,0.48,0),Vector3(0.025,0.28,0.025),Color("c06c79"),Vector3(0,0,-0.19))
	box(root,at+Vector3(-0.03,0.39,0),Vector3(0.065,0.065,0.065),Color("d57b78"))

static func water(root: Node3D, at: Vector3, dimensions: Vector2, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = dimensions
	mesh.mesh = plane
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
		box(root,Vector3(0,scale_value*1.32,0),Vector3(scale_value*1.25,scale_value*0.80,scale_value*1.18),color)
		box(root,Vector3(-scale_value*0.27,scale_value*1.75,scale_value*0.05),Vector3(scale_value*0.90,scale_value*0.55,scale_value*0.87),color.lightened(0.07))
		box(root,Vector3(scale_value*0.42,scale_value*1.30,-scale_value*0.13),Vector3(scale_value*0.57,scale_value*0.62,scale_value*0.70),color.darkened(0.06))

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
		"shrub", "snowdrift", "dune", "rock":
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
			for i in range(4):
				var x: float = float(i%2)*size*0.48-size*0.24
				var z: float = float(i/2)*size*0.4-size*0.20
				box(root,Vector3(x,size*0.22,z),Vector3(size*0.08,size*0.43,size*0.08),Color("b4b58c") if kind=="mushroom" else Color("829965"))
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
