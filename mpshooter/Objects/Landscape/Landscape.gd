extends Node3D


const GRID_SIZE = Vector3i(16, 16, 16)
const ISO_LEVEL = 0.5

# 3D масив щільностей (земля/повітря)
var density = []

func _ready():
	# Ініціалізація масиву щільностей
	density.resize(GRID_SIZE.x)
	for x in range(GRID_SIZE.x):
		density[x] = []
		for y in range(GRID_SIZE.y):
			density[x][y] = []
			for z in range(GRID_SIZE.z):
				# Простий приклад: сфера землі
				var pos = Vector3i(x, y, z) - GRID_SIZE / 2
				density[x][y][z] = 1.0 if pos.length() < 6 else 0.0
				#density[x][y][z] = pos.length() < 6.0 ? 1.0 : 0.0
	
	# Генерація меша
	var mesh = generate_mesh()
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)


func generate_mesh() -> ArrayMesh:
	var arrays = []
	var vertices = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Проходимо всі куби
	for x in range(GRID_SIZE.x - 1):
		for y in range(GRID_SIZE.y - 1):
			for z in range(GRID_SIZE.z - 1):
				var cube = get_cube(x, y, z)
				var tris = polygonize(cube)
				for tri in tris:
					var idx = vertices.size()
					vertices.append_array(tri)
					indices.append(idx)
					indices.append(idx+1)
					indices.append(idx+2)
	
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func get_cube(x, y, z) -> Array:
	# Повертає 8 вершин куба з їх щільностями
	var cube = []
	for dx in [0,1]:
		for dy in [0,1]:
			for dz in [0,1]:
				var pos = Vector3(x+dx, y+dy, z+dz)
				var val = density[x+dx][y+dy][z+dz]
				cube.append({"pos": pos, "val": val})
	return cube


func polygonize(cube: Array) -> Array:
	var tris = []
	# Тут має бути lookup‑таблиця Marching Cubes
	# Для прикладу — якщо половина вершин > ISO_LEVEL, малюємо один трикутник
	var inside = []
	for v in cube:
		if v["val"] > ISO_LEVEL:
			inside.append(v["pos"])
	if inside.size() >= 3:
		tris.append([inside[0], inside[1], inside[2]])
	return tris
