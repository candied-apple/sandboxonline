extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const CHUNK_SIZE = 256
const SUBDIVISION = 128 # Vertex density
const HEIGHT_SCALE = 20.0

func generate_terrain(terrain_seed: int) -> void:
	print("Generating terrain with seed: %d" % terrain_seed)
	var noise = FastNoiseLite.new()
	noise.seed = terrain_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.01
	noise.fractal_octaves = 5
	
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	plane_mesh.subdivide_width = SUBDIVISION
	plane_mesh.subdivide_depth = SUBDIVISION
	
	# Generate Surface
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from(plane_mesh, 0)
	
	var array_plane = surface_tool.commit()
	
	# Manipulate vertices based on noise
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(array_plane, 0)
	
	for i in range(mdt.get_vertex_count()):
		var vertex = mdt.get_vertex(i)
		# Get height from noise
		var h = noise.get_noise_2d(vertex.x, vertex.z) * HEIGHT_SCALE
		vertex.y = h
		mdt.set_vertex(i, vertex)
	
	# Recalculate normals
	array_plane.clear_surfaces()
	mdt.commit_to_surface(array_plane)
	
	# Assign Mesh
	mesh_instance.mesh = array_plane
	
	# Create Collision
	if collision_shape.shape:
		collision_shape.shape = array_plane.create_trimesh_shape()
	else:
		var shape = array_plane.create_trimesh_shape()
		collision_shape.shape = shape
