extends Packet

var time: float = 0.0

func get_packet_id() -> int:
	return 50

func serialize(buffer: StreamPeerBuffer) -> void:
	buffer.put_float(time)

func deserialize(buffer: StreamPeerBuffer) -> void:
	time = buffer.get_float()
