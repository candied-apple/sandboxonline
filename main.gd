extends Node

func _ready() -> void:
	var args = OS.get_cmdline_args()
	var is_server = "--server" in args or OS.has_feature("dedicated_server")
	
	var network_node = Node.new()
	network_node.name = "Network"
	add_child(network_node)
	
	if is_server:
		print("Starting as Server...")
		network_node.set_script(load("res://server/core/server.gd"))
	else:
		print("Starting as Client...")
		network_node.set_script(load("res://client/core/client.gd"))
		# Client script auto-connects in its _ready, which is called when script is set? 
		# No, set_script doesn't re-trigger _ready if the node is already in tree?
		# Actually, if we set script on a new node before adding to tree, it's safer.
	
	# Let's re-do: Load script, new(), name it, add child.
	network_node.queue_free() # remove the generic one
	
	var impl
	if is_server:
		impl = load("res://server/core/server.gd").new()
	else:
		impl = load("res://client/core/client.gd").new()
	
	impl.name = "Network"
	add_child(impl)
