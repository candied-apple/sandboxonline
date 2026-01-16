extends Node3D

const CHUNK_SIZE = 32
const HEIGHT_SCALE = 1.0

var chunks: Dictionary = {} # Vector2i -> MeshInstance3D
var terrain_material: Material

func _ready() -> void:
	if FileAccess.file_exists("res://assets/materials/terrain_shader_mat.tres"):
		terrain_material = load("res://assets/materials/terrain_shader_mat.tres")
	elif FileAccess.file_exists("res://assets/textures/terrain/grass.png"):
		# Fallback to standard
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/terrain/grass.png")
		terrain_material = mat
	else:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.FOREST_GREEN
		terrain_material = mat

func update_chunk(x: int, z: int, height_data: PackedFloat32Array) -> void:
	var key = Vector2i(x, z)
	
	if chunks.has(key):
		return
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var vertices_per_row = CHUNK_SIZE + 1
	
	for cz in range(vertices_per_row):
		for cx in range(vertices_per_row):
			var idx = cz * vertices_per_row + cx
			var h = 0.0
			if idx < height_data.size():
				h = height_data[idx]
			
			# UVs: Scale down to reduce repetition
			st.set_uv(Vector2(cx, cz) * 0.25)
			
			# Vertex
			st.add_vertex(Vector3(cx, h, cz))
	
	# Indices
	for cz in range(CHUNK_SIZE):
		for cx in range(CHUNK_SIZE):
			var top_left = cz * vertices_per_row + cx
			var top_right = top_left + 1
			var bottom_left = (cz + 1) * vertices_per_row + cx
			var bottom_right = bottom_left + 1
			
			# Triangle 1 (CCW)
			st.add_index(top_left)
			st.add_index(top_right)
			st.add_index(bottom_left)
			
			# Triangle 2 (CCW)
			st.add_index(top_right)
			st.add_index(bottom_right)
			st.add_index(bottom_left)
	
	st.generate_normals()
	var mesh = st.commit()
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = terrain_material
	mesh_instance.create_trimesh_collision()
	
	mesh_instance.position = Vector3(x * CHUNK_SIZE, 0, z * CHUNK_SIZE)
	
	add_child(mesh_instance)
	chunks[key] = mesh_instance
