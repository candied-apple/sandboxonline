extends Node

# PacketManager (Autoload)
# Handles packet registration and routing

var _packets: Dictionary = {} # Map<int, GDScript> (ID -> Packet Class)

func _ready() -> void:
	# Register Packets
	register_packet(1, load("res://modules/auth/packet_handshake.gd"))
	register_packet(10, load("res://modules/world/packet_spawn_player.gd"))
	register_packet(11, load("res://modules/world/packet_player_move.gd"))
	register_packet(12, load("res://modules/world/packet_despawn_player.gd"))
	register_packet(20, load("res://modules/chat/packet_chat.gd"))
	register_packet(31, load("res://modules/world/packet_chunk_data.gd"))
	register_packet(40, load("res://modules/world/packet_fly_ability.gd"))

func register_packet(id: int, packet_script: GDScript) -> void:
	if _packets.has(id):
		push_warning("Packet ID %d is already registered to %s. Overwriting." % [id, _packets[id].resource_path])
	_packets[id] = packet_script

func create_packet(id: int) -> Packet:
	if not _packets.has(id):
		printerr("Unknown Packet ID: %d" % id)
		return null
	return _packets[id].new()

func encode_packet(packet: Packet) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	buffer.put_u16(packet.get_packet_id()) # Write ID (2 bytes)
	packet.serialize(buffer) # Write Payload
	return buffer.data_array

func decode_packet(data: PackedByteArray) -> Packet:
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = data
	
	if buffer.get_size() < 2:
		return null
		
	var id = buffer.get_u16()
	var packet = create_packet(id)
	
	if packet:
		packet.deserialize(buffer)
		
	return packet
