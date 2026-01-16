extends Control

signal message_sent(text: String)
signal chat_toggled(is_open: bool)

@onready var chat_log: RichTextLabel = $ChatLog
@onready var chat_input: LineEdit = $ChatInput

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_chat"): # Enter key
		if chat_input.visible:
			_submit_message()
		else:
			_open_chat()
	elif event.is_action_pressed("ui_cancel"): # Esc key
		if chat_input.visible:
			_close_chat()

func _open_chat() -> void:
	chat_input.visible = true
	chat_input.grab_focus()
	emit_signal("chat_toggled", true)
	# Release mouse so we can type without spinning camera? 
	# Actually player controller handles mouse capture. We need to tell Client to disable player input.

func _close_chat() -> void:
	chat_input.visible = false
	chat_input.release_focus()
	chat_input.clear()
	emit_signal("chat_toggled", false)

func _submit_message() -> void:
	var text = chat_input.text.strip_edges()
	if not text.is_empty():
		emit_signal("message_sent", text)
	_close_chat()

func add_message(username: String, text: String) -> void:
	var color = "white"
	if username == "Server":
		color = "yellow"
	chat_log.append_text("\n[color=%s][b]%s:[/b] %s[/color]" % [color, username, text])
