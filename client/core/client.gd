extends Node

const PACKET_SPAWN_PLAYER = preload("res://modules/world/packet_spawn_player.gd")
const PACKET_PLAYER_MOVE = preload("res://modules/world/packet_player_move.gd")
const PACKET_DESPAWN_PLAYER = preload("res://modules/world/packet_despawn_player.gd")
const PACKET_CHAT = preload("res://modules/chat/packet_chat.gd")
const PACKET_CHUNK_DATA = preload("res://modules/world/packet_chunk_data.gd")
const PACKET_FLY_ABILITY = preload("res://modules/world/packet_fly_ability.gd")

var chat_ui: Node = null
var main_menu: Node = null

var local_player_node: Node3D = null
var last_sent_time: float = 0.0
var player_username: String = "Player"
var player_uuid: String = ""
var target_ip: String = "127.0.0.1"
var target_port: int = 7777

func _ready() -> void:
	# Show Main Menu
	var menu_scene = load("res://client/ui/main_menu.tscn")
	if menu_scene:
		main_menu = menu_scene.instantiate()
		main_menu.connect("connect_requested", _on_connect_requested)
		add_child(main_menu)

func _generate_uuid(username: String) -> String:
	var uuid_hash = username.md5_text()
	# Format as UUID: 8-4-4-4-12
	return "%s-%s-%s-%s-%s" % [
		uuid_hash.substr(0, 8),
		uuid_hash.substr(8, 4),
		uuid_hash.substr(12, 4),
		uuid_hash.substr(16, 4),
		uuid_hash.substr(20, 12)
	]

func _on_connect_requested(username: String, ip_string: String) -> void:
	player_username = username
	player_uuid = _generate_uuid(username)
	
	# Parse IP:PORT
	if ":" in ip_string:
		var parts = ip_string.split(":")
		target_ip = parts[0]
		target_port = int(parts[1])
	else:
		target_ip = ip_string
		target_port = 7777 # Fallback
	
	if not chat_ui:
		var chat_scene = load("res://client/ui/chat_ui.tscn")
		if chat_scene:
			chat_ui = chat_scene.instantiate()
			chat_ui.connect("message_sent", _on_chat_message_sent)
			chat_ui.connect("chat_toggled", _on_chat_toggled)
			add_child(chat_ui)
	
	connect_to_server()

func log_msg(msg: String) -> void:
	print(msg)

func connect_to_server() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(target_ip, target_port)
	if error != OK:
		log_msg("Failed to connect to server: %d" % error)
		return
	
	multiplayer.multiplayer_peer = peer
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	log_msg("Connecting to server at %s:%d..." % [target_ip, target_port])

func _on_connected_to_server() -> void:
	log_msg("Successfully connected to server!")
	if main_menu:
		main_menu.queue_free()
		main_menu = null
		
	# Send Handshake
	var packet = PacketHandshake.new()
	packet.message = "Hello from Client!"
	packet.username = player_username
	packet.uuid = player_uuid
	send_packet(packet)

func _on_connection_failed() -> void:
	log_msg("Connection failed.")
	_reset_game_state("Connection Failed: Server unreachable.")

func _on_server_disconnected() -> void:
	log_msg("Server disconnected.")
	_reset_game_state("Disconnected: Server closed or connection lost.")

func _reset_game_state(reason: String) -> void:
	# 1. Reset Input
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# 2. Clear Game Nodes
	if chat_ui:
		chat_ui.queue_free()
		chat_ui = null
		
	if has_node("World"):
		get_node("World").queue_free()
		
	local_player_node = null
	
	# 3. Restore Main Menu
	if not main_menu:
		var menu_scene = load("res://client/ui/main_menu.tscn")
		if menu_scene:
			main_menu = menu_scene.instantiate()
			main_menu.connect("connect_requested", _on_connect_requested)
			add_child(main_menu)
	
	# 4. Show Popup
	if main_menu.has_method("show_disconnect_reason"):
		main_menu.show_disconnect_reason(reason)

func send_packet(packet: Packet) -> void:
	var data = PacketManager.encode_packet(packet)
	if packet.get_packet_id() == 11: # PacketPlayerMove
		send_packet_to_server_unreliable.rpc_id(1, data)
	else:
		send_packet_to_server.rpc_id(1, data)

@rpc("any_peer", "call_remote", "reliable")
func send_packet_to_server(_data: PackedByteArray) -> void:
	pass

@rpc("any_peer", "call_remote", "unreliable")
func send_packet_to_server_unreliable(_data: PackedByteArray) -> void:
	pass

@rpc("authority", "call_remote", "reliable")
func receive_packet_from_server(data: PackedByteArray) -> void:
	_process_incoming_packet(data)

@rpc("authority", "call_remote", "unreliable")
func receive_packet_from_server_unreliable(data: PackedByteArray) -> void:
	_process_incoming_packet(data)

func _process_incoming_packet(data: PackedByteArray) -> void:
	var packet = PacketManager.decode_packet(data)
	if packet:
		_handle_packet(packet)

func _handle_packet(packet: Packet) -> void:
	if packet is PacketHandshake:
		log_msg("Server says: [color=green]%s[/color]" % packet.message)
	elif packet is PACKET_CHUNK_DATA:
		_handle_chunk_data(packet)
	elif packet is PACKET_SPAWN_PLAYER:
		_handle_spawn_player(packet)
	elif packet is PACKET_PLAYER_MOVE:
		_handle_player_move(packet)
	elif packet is PACKET_DESPAWN_PLAYER:
		_handle_despawn_player(packet)
	elif packet is PACKET_CHAT:
		_handle_chat(packet)
	elif packet is PACKET_FLY_ABILITY:
		_handle_fly_ability(packet)

func _handle_fly_ability(packet: PACKET_FLY_ABILITY) -> void:
	if local_player_node:
		local_player_node.can_fly_ability = packet.can_fly
		if not packet.can_fly:
			local_player_node.is_flying = false
		log_msg("Flight ability: %s" % ["enabled" if packet.can_fly else "disabled"])

func _handle_chunk_data(packet) -> void:
	# Ensure World/ChunkManager exists
	_ensure_world_loaded()
	
	if has_node("World/ChunkManager"):
		var cm = get_node("World/ChunkManager")
		cm.update_chunk(packet.chunk_x, packet.chunk_z, packet.height_data)

func _ensure_world_loaded() -> void:
	if not has_node("World"):
		var world_scene = load("res://modules/world/world.tscn")
		var world = world_scene.instantiate()
		world.name = "World"
		add_child(world)
		
		if world.has_node("Terrain"):
			world.get_node("Terrain").queue_free()
			
		var cm_script = load("res://modules/world/client_chunk_manager.gd")
		var cm = cm_script.new()
		cm.name = "ChunkManager"
		world.add_child(cm)

func _handle_spawn_player(packet) -> void:
	log_msg("Spawning player %d at %s" % [packet.id, packet.position])
	_ensure_world_loaded()
	
	# 2. Spawn Player
	var player_scene = load("res://modules/player/player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player_%d" % packet.id
	player.position = packet.position
	get_node("World").add_child(player)
	
	if player.has_method("set_username"):
		player.set_username(packet.username)
	
	if packet.id == multiplayer.get_unique_id():
		player.setup_local()
		local_player_node = player
	else:
		player.setup_puppet()

func _handle_player_move(packet) -> void:
	if packet.id == multiplayer.get_unique_id():
		return
		
	var player_name = "Player_%d" % packet.id
	if has_node("World/" + player_name):
		var player = get_node("World/" + player_name)
		if player.has_method("update_puppet_state"):
			player.update_puppet_state(packet.position, packet.rotation)
		else:
			player.position = packet.position
			player.rotation = packet.rotation

func _handle_chat(packet) -> void:
	if chat_ui:
		chat_ui.add_message(packet.username, packet.message)

func _handle_despawn_player(packet) -> void:
	log_msg("Despawning player %d" % packet.id)
	var player_name = "Player_%d" % packet.id
	if has_node("World/" + player_name):
		get_node("World/" + player_name).queue_free()

func _physics_process(_delta: float) -> void:
	if local_player_node:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_sent_time > 0.05:
			last_sent_time = current_time
			var packet = PACKET_PLAYER_MOVE.new()
			packet.id = multiplayer.get_unique_id()
			packet.position = local_player_node.position
			packet.rotation = local_player_node.rotation
			send_packet(packet)

func _on_chat_message_sent(text: String) -> void:
	var packet = PacketChat.new()
	packet.message = text
	send_packet(packet)

func _on_chat_toggled(is_open: bool) -> void:
	if local_player_node and local_player_node.has_method("set_input_enabled"):
		local_player_node.set_input_enabled(not is_open)