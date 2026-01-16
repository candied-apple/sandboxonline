extends Node

const PACKET_CHUNK_DATA = preload("res://modules/world/packet_chunk_data.gd")
const RegionManager = preload("res://server/core/region_manager.gd")

var chunk_size: int = 32
var world_size: int = 0
var noise: FastNoiseLite
var generated_chunks: Dictionary = {} # Vector2i -> PackedFloat32Array

# Tracking which chunks a player has loaded
# ID -> Dictionary[Vector2i, bool]
var player_loaded_chunks: Dictionary = {} 

var region_manager: Node = null

func setup(world_seed: int, p_chunk_size: int, p_world_size: int) -> void:
	chunk_size = p_chunk_size
	world_size = p_world_size
	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.02
	
	region_manager = RegionManager.new()
	region_manager.name = "RegionManager"
	add_child(region_manager)

func get_chunk_data(x: int, z: int) -> PackedFloat32Array:
	var key = Vector2i(x, z)
	if generated_chunks.has(key):
		return generated_chunks[key]
	
	# Try loading from Region Manager
	var disk_data = region_manager.get_chunk(x, z)
	if disk_data.size() > 0:
		generated_chunks[key] = disk_data
		return disk_data
	
	# Generate
	var data = PackedFloat32Array()
	data.resize((chunk_size + 1) * (chunk_size + 1))
	
	var idx = 0
	for cz in range(chunk_size + 1):
		for cx in range(chunk_size + 1):
			var global_x = x * chunk_size + cx
			var global_z = z * chunk_size + cz
			
			# Check Bounds if world is finite
			if world_size > 0:
				if abs(global_x) > world_size or abs(global_z) > world_size:
					data[idx] = -100.0 # Void
					idx += 1
					continue
			
			var h = noise.get_noise_2d(global_x, global_z) * 20.0
			data[idx] = h
			idx += 1
			
	generated_chunks[key] = data
	region_manager.save_chunk(x, z, data)
	return data

func save_world() -> void:
	if region_manager:
		region_manager.save_all()

func process_player(player_id: int, position: Vector3, view_distance: int, server_node: Node) -> void:
	if not player_loaded_chunks.has(player_id):
		player_loaded_chunks[player_id] = {}
	
	var chunk_x = floor(position.x / chunk_size)
	var chunk_z = floor(position.z / chunk_size)
	
	# Simple grid loop
	for z in range(chunk_z - view_distance, chunk_z + view_distance + 1):
		for x in range(chunk_x - view_distance, chunk_x + view_distance + 1):
			var key = Vector2i(x, z)
			
			if world_size > 0:
				var max_chunks = int(float(world_size) / float(chunk_size))
				if abs(x) > max_chunks or abs(z) > max_chunks:
					continue
			
			if not player_loaded_chunks[player_id].has(key):
				var data = get_chunk_data(x, z)
				var packet = PACKET_CHUNK_DATA.new()
				packet.chunk_x = x
				packet.chunk_z = z
				packet.height_data = data
				server_node.send_packet_to_client(player_id, packet)
				player_loaded_chunks[player_id][key] = true