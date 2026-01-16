class_name PacketPlayerMove
extends Packet

var id: int = 0
var position: Vector3 = Vector3.ZERO
var rotation: Vector3 = Vector3.ZERO # We mainly need Y for body, X for camera usually

func get_packet_id() -> int:
	return 11

func serialize(buffer: StreamPeerBuffer) -> void:
	buffer.put_u32(id)
	buffer.put_float(position.x)
	buffer.put_float(position.y)
	buffer.put_float(position.z)
	buffer.put_float(rotation.x)
	buffer.put_float(rotation.y)
	buffer.put_float(rotation.z)

func deserialize(buffer: StreamPeerBuffer) -> void:
	id = buffer.get_u32()
	position.x = buffer.get_float()
	position.y = buffer.get_float()
	position.z = buffer.get_float()
	rotation.x = buffer.get_float()
	rotation.y = buffer.get_float()
	rotation.z = buffer.get_float()
