class_name PacketDespawnPlayer
extends Packet

var id: int = 0

func get_packet_id() -> int:
	return 12

func serialize(buffer: StreamPeerBuffer) -> void:
	buffer.put_u32(id)

func deserialize(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
