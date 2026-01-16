class_name PacketSpawnPlayer
extends Packet

var position: Vector3 = Vector3.ZERO
var id: int = 0
var username: String = ""

func get_packet_id() -> int:
	return 10

func serialize(buffer: StreamPeerBuffer) -> void:
	buffer.put_u32(id)
	buffer.put_float(position.x)
	buffer.put_float(position.y)
	buffer.put_float(position.z)
	buffer.put_utf8_string(username)

func deserialize(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
	position.x = buffer.get_float()
	position.y = buffer.get_float()
	position.z = buffer.get_float()
	username = buffer.get_utf8_string()
