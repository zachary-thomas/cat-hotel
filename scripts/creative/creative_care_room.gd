extends RefCounted
## Small, isolated sets; these props never enter the hotel's furniture model.
const THEMES = [
	["FFF1D9", "DCC099", "EDB95C", "B4D9B4"],
	["E8F3EF", "D9C6AC", "8FCBD2", "B6E4EB"],
	["E5ECD9", "BA9472", "99B37A", "88B49B"],
	["F4EBE6", "BBA597", "C49187", "D4E4EF"]
]

static func box(parent: Node3D, at: Vector3, dimensions: Vector3, tint: Color) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = dimensions; piece.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = tint; material.roughness = 1.0
	piece.material_override = material; piece.position = at; parent.add_child(piece)
	return piece

static func ball(parent: Node3D, at: Vector3, radius: float, tint: Color) -> MeshInstance3D:
	var piece := box(parent, at, Vector3.ONE, tint)
	var mesh := SphereMesh.new(); mesh.radius = radius; mesh.height = radius * 2; piece.mesh = mesh
	return piece

static func build(parent: Node3D, hotel: int) -> Node3D:
	var colors: Array = THEMES[clampi(hotel,0,3)]
	box(parent,Vector3(0,-0.09,0),Vector3(12,0.16,12),Color(colors[1]))
	for x in range(-12,13): box(parent,Vector3(x*0.5,0,0),Vector3(0.012,0.006,12),Color(colors[1]).darkened(0.10))
	box(parent,Vector3(0,3,-1.7),Vector3(12,6.2,0.1),Color(colors[0]))
	box(parent,Vector3(0,0.15,-1.62),Vector3(9,0.22,0.06),Color(colors[1]).lightened(0.2))
	box(parent,Vector3(-1.35,1.65,-1.6),Vector3(1.2,1.65,0.08),Color("BA9472"))
	box(parent,Vector3(-1.35,1.65,-1.53),Vector3(1.05,1.5,0.05),Color(colors[3]))
	for at in [Vector3(-1.35,1.65,-1.48)]:
		box(parent,at,Vector3(1.08,0.06,0.06),Color("FFF8EB"))
		box(parent,at,Vector3(0.06,1.5,0.06),Color("FFF8EB"))
	box(parent,Vector3(1.25,1.65,-1.58),Vector3(0.72,0.82,0.07),Color(colors[1]))
	box(parent,Vector3(1.25,1.65,-1.53),Vector3(0.59,0.68,0.04),Color(colors[2]).lightened(0.2))
	ball(parent,Vector3(1.25,1.67,-1.48),0.17,Color("FFF4D8")).scale.z=0.12
	var rug := ball(parent,Vector3(0,0.025,0.25),1.5,Color(colors[2]).lightened(0.25)); rug.scale=Vector3(1,0.035,0.85)
	box(parent,Vector3(-1.65,0.25,-0.85),Vector3(0.35,0.5,0.35),Color("BC8D6F"))
	for i in range(5):
		var leaf := box(parent,Vector3(-1.65+sin(i*2.0)*0.14,0.6+i*0.10,-0.85),Vector3(0.32,0.10,0.15),Color("729E7B"))
		leaf.rotation.z=sin(i*2.0)*0.5
	if hotel == 3:
		box(parent,Vector3(1.6,0.55,-1.15),Vector3(0.72,1.1,0.3),Color("AE8170"))
		box(parent,Vector3(1.6,0.45,-0.97),Vector3(0.48,0.56,0.05),Color("6E514B"))
		box(parent,Vector3(1.6,0.29,-0.92),Vector3(0.35,0.16,0.07),Color("F7B660"))
	var cushion := Node3D.new(); cushion.name="CareCushion"; parent.add_child(cushion)
	var pillow := ball(cushion,Vector3(0,0.14,0),0.72,Color(colors[2])); pillow.scale=Vector3(1,0.22,0.8)
	cushion.visible=false
	return cushion
