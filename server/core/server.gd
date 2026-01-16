extends Node

const PACKET_SPAWN_PLAYER = preload("res://modules/world/packet_spawn_player.gd")
const PACKET_PLAYER_MOVE = preload("res://modules/world/packet_player_move.gd")
const PACKET_DESPAWN_PLAYER = preload("res://modules/world/packet_despawn_player.gd")
const PACKET_CHAT = preload("res://modules/chat/packet_chat.gd")
const ChunkSystem = preload("res://server/core/chunk_system.gd")
const COMMAND_MANAGER = preload("res://server/core/command_manager.gd")

var server_settings = {
	"port": 7777,
	"max_clients": 100,
	"seed": 0,
	"world_size": 0,
	"chunk_size": 32,
	"view_distance": 4,
	"ops": [],
	"permissions": {}
}

var connected_players: Dictionary = {} # ID -> Dictionary (Data)
var chunk_system: Node = null
var command_manager: RefCounted = null
var console_thread: Thread = null

func _ready() -> void:
	load_settings()
	
	chunk_system = ChunkSystem.new()
	chunk_system.setup(server_settings["seed"], server_settings["chunk_size"], server_settings["world_size"])
	add_child(chunk_system)
	
	command_manager = COMMAND_MANAGER.new(self)
	
	start_server()
	
	# Start Console Thread
	console_thread = Thread.new()
	console_thread.start(_console_input_loop)

func _console_input_loop() -> void:
	while true:
		var line = OS.read_string_from_stdin()
		if line.length() > 0:
			call_deferred("_handle_console_command", line.strip_edges())
		else:
			OS.delay_msec(100)

func _handle_console_command(cmd: String) -> void:
	if command_manager:
		# If user typed "op alp", we treat it as "/op alp" or just "op alp"
		if not cmd.begins_with("/"):
			cmd = "/" + cmd
		command_manager.handle_command(-1, cmd)

var save_timer: float = 0.0
const SAVE_INTERVAL = 60.0

func _physics_process(delta: float) -> void:
	# Update chunks for players
	if chunk_system:
		for id in connected_players:
			var p = connected_players[id]
			if p.has("position"):
				chunk_system.process_player(id, p["position"], server_settings["view_distance"], self)
	
	# Autosave
	save_timer += delta
	if save_timer >= SAVE_INTERVAL:
		save_timer = 0.0
		save_world()

func _exit_tree() -> void:
	if console_thread and console_thread.is_alive():
		console_thread.wait_to_finish()
	save_world()

func save_world() -> void:
	if chunk_system and chunk_system.has_method("save_world"):
		chunk_system.save_world()
	save_settings_to_disk()

func stop_server() -> void:
	print("Stopping server...")
	save_world()
	get_tree().quit()

func load_settings() -> void:
	if FileAccess.file_exists("res://server_settings.json"):
		var file = FileAccess.open("res://server_settings.json", FileAccess.READ)
		var text = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(text)
		if error == OK:
			var data = json.data
			if data.has("port"): server_settings["port"] = int(data["port"])
			if data.has("max_clients"): server_settings["max_clients"] = int(data["max_clients"])
			if data.has("seed"): server_settings["seed"] = int(data["seed"])
			if data.has("world_size"): server_settings["world_size"] = int(data["world_size"])
			if data.has("chunk_size"): server_settings["chunk_size"] = int(data["chunk_size"])
			if data.has("view_distance"): server_settings["view_distance"] = int(data["view_distance"])
			if data.has("ops"): server_settings["ops"] = data["ops"]
			if data.has("permissions"): server_settings["permissions"] = data["permissions"]
		else:
			printerr("Failed to parse server_settings.json")
	
	if server_settings["seed"] == 0:
		randomize()
		server_settings["seed"] = randi()
		print("Generated random seed: %d" % server_settings["seed"])
	else:
		print("Using configured seed: %d" % server_settings["seed"])

func save_settings_to_disk() -> void:
	var file = FileAccess.open("res://server_settings.json", FileAccess.WRITE)
	if file:
		var json = JSON.stringify(server_settings, "\t")
		file.store_string(json)
		file.close()

func start_server() -> void:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(server_settings["port"], server_settings["max_clients"])
	if error != OK:
		printerr("Failed to start server: %d" % error)
		return
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	
	print("Server started on port %d" % server_settings["port"])

func _on_peer_connected(id: int) -> void:
	print("Client connected: %d" % id)
	# Initialize player data
	connected_players[id] = { "username": "Unknown", "position": Vector3(0, 5, 0) }

func _on_peer_disconnected(id: int) -> void:
	print("Client disconnected: %d" % id)
	if connected_players.has(id):
		connected_players.erase(id)
	
	var packet = PACKET_DESPAWN_PLAYER.new()
	packet.id = id
	
	for peer_id in connected_players:
		send_packet_to_client(peer_id, packet)

@rpc("any_peer", "call_remote", "reliable")
func send_packet_to_server(data: PackedByteArray) -> void:
	_process_incoming_data(data)

@rpc("any_peer", "call_remote", "unreliable")
func send_packet_to_server_unreliable(data: PackedByteArray) -> void:
	_process_incoming_data(data)

func _process_incoming_data(data: PackedByteArray) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	var packet = PacketManager.decode_packet(data)
	if packet:
		_handle_packet(sender_id, packet)
	else:
		printerr("Received invalid packet from %d" % sender_id)

func _handle_packet(sender_id: int, packet: Packet) -> void:
	if packet is PacketHandshake:
		print("Handshake from %d: %s (Username: %s, UUID: %s)" % [sender_id, packet.message, packet.username, packet.uuid])
		# Update Username
		if connected_players.has(sender_id):
			connected_players[sender_id]["username"] = packet.username
			connected_players[sender_id]["uuid"] = packet.uuid
			
		# Respond back
		var response = PacketHandshake.new()
		response.message = "Welcome %s!" % packet.username
		send_packet_to_client(sender_id, response)
		
		# --- SPAWN LOGIC ---
		var new_spawn = PACKET_SPAWN_PLAYER.new()
		new_spawn.id = sender_id
		new_spawn.position = Vector3(0, 50, 0)
		new_spawn.username = packet.username
		
		for peer_id in connected_players:
			if peer_id == sender_id: continue
			
			# Send new guy to old guy
			send_packet_to_client(peer_id, new_spawn)
			
			# Send old guy to new guy
			var old_spawn = PACKET_SPAWN_PLAYER.new()
			old_spawn.id = peer_id
			if connected_players[peer_id].has("position"):
				old_spawn.position = connected_players[peer_id]["position"]
			else:
				old_spawn.position = Vector3(0, 50, 0)
			old_spawn.username = connected_players[peer_id]["username"]
			send_packet_to_client(sender_id, old_spawn)
		
		# Send new guy to himself
		send_packet_to_client(sender_id, new_spawn)
		
	elif packet is PACKET_PLAYER_MOVE:
		# Update internal position
		if connected_players.has(sender_id):
			connected_players[sender_id]["position"] = packet.position
			
		# Broadcast to others
		for peer_id in connected_players:
			if peer_id != sender_id:
				send_packet_to_client(peer_id, packet)
				
	elif packet is PACKET_CHAT:
		# Command Check
		if packet.message.begins_with("/"):
			if command_manager:
				command_manager.handle_command(sender_id, packet.message)
		else:
			# Broadcast chat
			var username = "Unknown"
			if connected_players.has(sender_id):
				username = connected_players[sender_id]["username"]
			
			print("[Chat] %s: %s" % [username, packet.message])
				
			var broadcast = PACKET_CHAT.new()
			broadcast.sender_id = sender_id
			broadcast.username = username
			broadcast.message = packet.message
			
			for peer_id in connected_players:
				send_packet_to_client(peer_id, broadcast)

func send_packet_to_client(target_id: int, packet: Packet) -> void:
	var data = PacketManager.encode_packet(packet)
	
	if packet.get_packet_id() == 11: # PacketPlayerMove
		# We assume the client has 'receive_packet_from_server_unreliable'
		receive_packet_from_server_unreliable.rpc_id(target_id, data)
	else:
		receive_packet_from_server.rpc_id(target_id, data)

@rpc("authority", "call_remote", "reliable")
func receive_packet_from_server(_data: PackedByteArray) -> void:
	pass

@rpc("authority", "call_remote", "unreliable")
func receive_packet_from_server_unreliable(_data: PackedByteArray) -> void:
	pass