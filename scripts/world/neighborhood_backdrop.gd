extends RefCounted
## Scenery deliberately extends far beyond the bounded, explorable neighborhood.
static func build(world, hotel: int) -> void:
	var ground: Color = [Color("b4c797"),Color("e5d3af"),Color("94ab85"),Color("dfebee")][hotel]
	var lawn: Color = [Color("bfd49d"),Color("e9d9b6"),Color("acbd8c"),Color("edf3f1")][hotel]
	if hotel == 1:
		world.box(Vector3(0,-0.55,-117),Vector3(512,0.4,266),ground)
		world.box(Vector3(0,-0.20,14.0),Vector3(512,0.25,3.0),Color("efdfb9"))
		var water := MeshInstance3D.new()
		water.name="SeasideWater"
		var plane := PlaneMesh.new(); plane.size=Vector2(512,256)
		water.mesh=plane; water.position=Vector3(0,-0.32,143.5)
		var material := ShaderMaterial.new(); material.shader=world.WATER
		material.set_shader_parameter("shore_z",15.5)
		water.material_override=material
		water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.animated_materials.append(material); world.building.add_child(water)
	else:
		world.box(Vector3(0,-0.55,0),Vector3(512,0.4,512),ground)
	# Free starting side gardens; individual purchased plots are drawn by Neighborhood.
	world.box(Vector3(0,-0.23,-10),Vector3(36,0.18,32),lawn)
	for side in [-1,1]:
		world.box(Vector3(side*35,-0.20,-90),Vector3(4.5,0.2,205),Color("80909b"))
		world.box(Vector3(side*32,-0.14,-16),Vector3(1.2,0.16,56),Color("e5d9bb"))
		for z in range(-180,10,5):
			world.box(Vector3(side*35,-0.09,z),Vector3(0.12,0.02,1.8),Color("f4dfb1"))
	# Small houses, front steps, window boxes, and trees continue down both streets.
	for side in [-1,1]:
		for row in range(12):
			var p := Vector3(side*(43.0+(row%2)*1.5),-0.2,5.0-row*13.0)
			_house(world,p,row,hotel)
			world._tree(p+Vector3(side*5,0,3.5),hotel==1)
	for row in range(7):
		for x in [-24.0,-11.0,3.0,17.0,29.0]:
			var p := Vector3(x,-0.2,-49-row*15)
			_house(world,p,row+int(x),hotel)
	if hotel != 1:
		world.box(Vector3(0,-0.13,14.4),Vector3(512,0.18,2.1),Color("e5d9bb"))
		for x in range(-150,151,14):
			_house(world,Vector3(x,-0.2,23),absi(x),hotel)
			world._tree(Vector3(x+5,-0.3,17),false)
		for x in range(-150,151,18):
			_house(world,Vector3(x,-0.2,44),absi(x+1),hotel)
	else:
		# Beach loungers stay on the sand, above the single continuous ocean surface.
		for x in range(-90,91,12):
			world.box(Vector3(x,0.0,13.8),Vector3(1.3,0.16,1.6),Color("de9d8d"))
			world._tree(Vector3(x+4,-0.25,13.5),true)

static func _house(world, p: Vector3, index: int, hotel: int) -> void:
	var wall: Color = [Color("edc7af"),Color("bfced1"),Color("d6c3df"),Color("eddcae")][posmod(index,4)]
	var roof: Color = Color("e6eded") if hotel==3 else [Color("b87774"),Color("789b98"),Color("8594a9")][posmod(index,3)]
	world.box(p+Vector3(0,1.55,0),Vector3(6.4,3.1,5.4),wall)
	for tier in range(4):
		world.box(p+Vector3(0,3.15+tier*0.28,0),Vector3(7.1-tier*0.65,0.32,6.1-tier*0.6),roof)
	world.box(p+Vector3(0,0.15,3.3),Vector3(2,0.3,1.2),Color("dad2bb"))
	world.box(p+Vector3(0,0.95,2.74),Vector3(1,1.9,0.12),Color("647e85"))
	for x in [-2,2]:
		world.box(p+Vector3(x,1.8,2.74),Vector3(1.3,1.3,0.12),Color("fcf0c7"))
		world.box(p+Vector3(x,1.8,2.82),Vector3(0.08,1.3,0.08),Color("7d9f9e"))
		world.box(p+Vector3(x,1.8,2.83),Vector3(1.3,0.08,0.08),Color("7d9f9e"))
		world.plant(p+Vector3(x,0.5,3.0),0.55,true)
