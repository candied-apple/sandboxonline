class_name CommandManager
extends RefCounted

var server_node: Node

func _init(server: Node) -> void:
	server_node = server

func handle_command(sender_id: int, message: String) -> void:
	var parts = message.split(" ", false)
	if parts.size() == 0: return
	var cmd = parts[0].substr(1) # Remove /
	
	match cmd:
		"op": _handle_op(sender_id, parts)
		"deop": _handle_deop(sender_id, parts)
		"stop": _handle_stop(sender_id)
		"fly": _handle_fly(sender_id, parts)
		_: _send_system_message(sender_id, "Unknown command: " + cmd)

func _has_permission(sender_id: int, node: String) -> bool:
	if sender_id == -1: return true # Console is SuperUser
	if not server_node.connected_players.has(sender_id): return false
	
	var uuid = server_node.connected_players[sender_id]["uuid"]
	var ops: Array = server_node.server_settings["ops"]
	
	# Check OP list first
	if uuid in ops: return true
	
	# Check Granular Permissions
	var perms: Dictionary = server_node.server_settings["permissions"]
	if perms.has(uuid):
		var user_perms: Array = perms[uuid]
		if "*" in user_perms: return true
		return node in user_perms
		
	return false

func _handle_op(sender_id: int, parts: PackedStringArray) -> void:
	if not _has_permission(sender_id, "server.command.op"):
		_send_system_message(sender_id, "You do not have permission (server.command.op).")
		return

	if parts.size() < 2:
		_send_system_message(sender_id, "Usage: /op <username>")
		return
		
	var target_name = parts[1]
	var target_uuid = _find_uuid_by_name(target_name)
	
	if target_uuid == "":
		_send_system_message(sender_id, "Player not found: " + target_name)
		return
		
	var ops: Array = server_node.server_settings["ops"]
	if not target_uuid in ops:
		ops.append(target_uuid)
		server_node.server_settings["ops"] = ops
		server_node.save_settings_to_disk()
		_send_system_message(sender_id, "Opped " + target_name)
		_broadcast_message(target_name + " is now an operator.")
	else:
		_send_system_message(sender_id, target_name + " is already an operator.")

func _handle_deop(sender_id: int, parts: PackedStringArray) -> void:
	if not _has_permission(sender_id, "server.command.deop"):
		_send_system_message(sender_id, "You do not have permission (server.command.deop).")
		return

	if parts.size() < 2:
		_send_system_message(sender_id, "Usage: /deop <username>")
		return
		
	var target_name = parts[1]
	var target_uuid = _find_uuid_by_name(target_name)
	
	if target_uuid == "":
		_send_system_message(sender_id, "Player not found: " + target_name)
		return
		
	var ops: Array = server_node.server_settings["ops"]
	if target_uuid in ops:
		ops.erase(target_uuid)
		server_node.server_settings["ops"] = ops
		server_node.save_settings_to_disk()
		_send_system_message(sender_id, "De-opped " + target_name)
		_broadcast_message(target_name + " is no longer an operator.")
	else:
		_send_system_message(sender_id, target_name + " is not an operator.")

func _handle_stop(sender_id: int) -> void:
	if not _has_permission(sender_id, "server.command.stop"):
		_send_system_message(sender_id, "You do not have permission (server.command.stop).")
		return
	
	_broadcast_message("Server stopping...")
	server_node.stop_server()

func _handle_fly(sender_id: int, parts: PackedStringArray) -> void:
	if not _has_permission(sender_id, "server.command.fly"):
		_send_system_message(sender_id, "You do not have permission (server.command.fly).")
		return

	var target_id = sender_id
	var target_name = ""
	
	if parts.size() >= 2:
		target_name = parts[1]
		var found_id = -1
		for peer_id in server_node.connected_players:
			if server_node.connected_players[peer_id]["username"] == target_name:
				found_id = peer_id
				break
		if found_id == -1:
			_send_system_message(sender_id, "Player not found: " + target_name)
			return
		target_id = found_id
	else:
		if sender_id == -1:
			_send_system_message(sender_id, "Usage: fly <username> (from console)")
			return
		target_name = server_node.connected_players[sender_id]["username"]

	# Toggle flight
	var p_data = server_node.connected_players[target_id]
	var can_fly = not p_data.get("can_fly", false)
	p_data["can_fly"] = can_fly
	
	var packet = load("res://modules/world/packet_fly_ability.gd").new()
	packet.can_fly = can_fly
	server_node.send_packet_to_client(target_id, packet)
	
	_send_system_message(sender_id, "Flight %s for %s" % ["enabled" if can_fly else "disabled", target_name])

func _find_uuid_by_name(name: String) -> String:
	for peer_id in server_node.connected_players:
		var p = server_node.connected_players[peer_id]
		if p["username"] == name:
			return p["uuid"]
	return ""

func _send_system_message(target_id: int, text: String) -> void:
	if target_id == -1:
		print("[System] " + text)
		return
		
	var packet = load("res://modules/chat/packet_chat.gd").new()
	packet.sender_id = 0
	packet.username = "Server"
	packet.message = text
	server_node.send_packet_to_client(target_id, packet)

func _broadcast_message(text: String) -> void:
	var packet = load("res://modules/chat/packet_chat.gd").new()
	packet.sender_id = 0
	packet.username = "Server"
	packet.message = text
	for peer_id in server_node.connected_players:
		server_node.send_packet_to_client(peer_id, packet)
