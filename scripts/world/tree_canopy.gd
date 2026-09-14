extends RefCounted
## One watertight crown: shared/internal voxel faces are never submitted.
static func create(palette: Array) -> ArrayMesh:
	var cells: Dictionary = {}
	for y in range(4):
		for x in range(-2, 3):
			for z in range(-2, 3):
				var radius: int = 2 if y == 0 or y == 3 else 5
				if x * x + z * z <= radius:
					cells[Vector3i(x, y, z)] = palette[posmod(x * 13 + y * 7 + z * 3, palette.size())]
	var cube = BoxMesh.new()
	cube.size = Vector3.ONE
	var source: Array = cube.get_mesh_arrays()
	var src_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	for cell in cells:
		for i in range(0, indices.size(), 3):
			var normal: Vector3 = src_normals[indices[i]]
			if cells.has(cell + Vector3i(normal)):
				continue
			for j in range(3):
				var k: int = indices[i+j]
				vertices.append((Vector3(cell) + src_vertices[k]) * 0.57)
				normals.append(src_normals[k])
				colors.append(cells[cell])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
