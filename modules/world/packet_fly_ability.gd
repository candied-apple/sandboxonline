class_name PacketFlyAbility
extends Packet

var can_fly: bool = false

func get_packet_id() -> int:
	return 40

func serialize(buffer: StreamPeerBuffer) -> void:
	buffer.put_8(1 if can_fly else 0)

func deserialize(buffer: StreamPeerBuffer) -> void:
	can_fly = buffer.get_8() == 1
