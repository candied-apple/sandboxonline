class_name Packet
extends RefCounted

# Base Packet class
# All packets must inherit from this and implement serialize/deserialize

func get_packet_id() -> int:
	return -1

func serialize(_buffer: StreamPeerBuffer) -> void:
	pass

func deserialize(_buffer: StreamPeerBuffer) -> void:
	pass
