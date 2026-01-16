class_name PacketChat
extends Packet

var sender_id: int = 0
var username: String = ""
var message: String = ""

func get_packet_id() -> int:
	return 20

func serialize(buffer: StreamPeerBuffer) -> void:
	buffer.put_u32(sender_id)
	buffer.put_utf8_string(username)
	buffer.put_utf8_string(message)

func deserialize(buffer: StreamPeerBuffer) -> void:
	sender_id = buffer.get_u32()
	username = buffer.get_utf8_string()
	message = buffer.get_utf8_string()
