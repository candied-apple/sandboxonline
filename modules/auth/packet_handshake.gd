class_name PacketHandshake
extends Packet

var message: String = ""
var username: String = ""
var uuid: String = ""

func get_packet_id() -> int:
	return 1

func serialize(buffer: StreamPeerBuffer) -> void:
	buffer.put_utf8_string(message)
	buffer.put_utf8_string(username)
	buffer.put_utf8_string(uuid)

func deserialize(buffer: StreamPeerBuffer) -> void:
	message = buffer.get_utf8_string()
	username = buffer.get_utf8_string()
	uuid = buffer.get_utf8_string()
