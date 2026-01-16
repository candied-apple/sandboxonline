class_name PacketChunkData
extends Packet

var chunk_x: int = 0
var chunk_z: int = 0
var height_data: PackedFloat32Array = PackedFloat32Array()

func get_packet_id() -> int:
	return 31

func serialize(buffer: StreamPeerBuffer) -> void:
	buffer.put_32(chunk_x)
	buffer.put_32(chunk_z)
	buffer.put_32(height_data.size())
	for h in height_data:
		buffer.put_float(h)

func deserialize(buffer: StreamPeerBuffer) -> void:
	chunk_x = buffer.get_32()
	chunk_z = buffer.get_32()
	var count = buffer.get_32()
	height_data.resize(count)
	for i in range(count):
		height_data[i] = buffer.get_float()
