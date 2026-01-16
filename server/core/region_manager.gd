extends Node

const REGION_SIZE = 32
const SAVE_DIR = "user://saves/world/regions/"

# Cache of loaded regions
# Vector2i(region_x, region_z) -> Dictionary { "chunks": {}, "dirty": bool }
var active_regions: Dictionary = {}

func _ready() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func save_all() -> void:
	print("Saving world regions...")
	for key in active_regions.keys():
		save_region(key.x, key.y)

func get_chunk(cx: int, cz: int) -> PackedFloat32Array:
	var rx = floor(float(cx) / REGION_SIZE)
	var rz = floor(float(cz) / REGION_SIZE)
	var region = _get_or_load_region(rx, rz)
	
	# Local coordinates within region
	# If cx is negative, modulo works differently in GDScript? 
	# posmod() is safer.
	var lx = posmod(cx, REGION_SIZE)
	var lz = posmod(cz, REGION_SIZE)
	var key = Vector2i(lx, lz)
	
	if region["chunks"].has(key):
		return region["chunks"][key]
	
	return PackedFloat32Array()

func save_chunk(cx: int, cz: int, data: PackedFloat32Array) -> void:
	var rx = floor(float(cx) / REGION_SIZE)
	var rz = floor(float(cz) / REGION_SIZE)
	var region = _get_or_load_region(rx, rz)
	
	var lx = posmod(cx, REGION_SIZE)
	var lz = posmod(cz, REGION_SIZE)
	var key = Vector2i(lx, lz)
	
	region["chunks"][key] = data
	region["dirty"] = true
	
	# Autosave strategy? For now, we rely on periodic save or explicit save.
	# Or simple write-through if we want safety, but that defeats the purpose.
	# We'll save on shutdown or periodical timer.

func _get_or_load_region(rx: int, rz: int) -> Dictionary:
	var key = Vector2i(rx, rz)
	if active_regions.has(key):
		return active_regions[key]
	
	# Load from disk
	var region_data = { "chunks": {}, "dirty": false }
	var path = _get_region_path(rx, rz)
	
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			# Format: Count (u32) -> [lx, lz, uncomp_len, comp_len, data]
			var count = file.get_32()
			for i in range(count):
				var lx = file.get_8()
				var lz = file.get_8()
				var len_uncompressed = file.get_32()
				var len_compressed = file.get_32()
				var compressed = file.get_buffer(len_compressed)
				
				var decompressed = compressed.decompress(len_uncompressed, FileAccess.COMPRESSION_ZSTD)
				if decompressed:
					var float_data = decompressed.to_float32_array()
					region_data["chunks"][Vector2i(lx, lz)] = float_data
				else:
					printerr("Failed to decompress chunk %d,%d in region %d,%d" % [lx, lz, rx, rz])
			
			file.close()
			
	active_regions[key] = region_data
	return region_data

func save_region(rx: int, rz: int) -> void:
	var key = Vector2i(rx, rz)
	if not active_regions.has(key): return
	var region = active_regions[key]
	
	if not region["dirty"]: return
	
	var path = _get_region_path(rx, rz)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var chunks = region["chunks"]
		file.store_32(chunks.size())
		
		for ckey in chunks:
			var lx = ckey.x
			var lz = ckey.y
			var data: PackedFloat32Array = chunks[ckey]
			var bytes = data.to_byte_array()
			var uncomp_size = bytes.size()
			var compressed = bytes.compress(FileAccess.COMPRESSION_ZSTD)
			
			file.store_8(lx)
			file.store_8(lz)
			file.store_32(uncomp_size)
			file.store_32(compressed.size())
			file.store_buffer(compressed)
		
		file.close()
		region["dirty"] = false
		# print("Saved Region %d,%d" % [rx, rz])

func _get_region_path(rx: int, rz: int) -> String:
	return SAVE_DIR + "r.%d.%d.bin" % [rx, rz]
