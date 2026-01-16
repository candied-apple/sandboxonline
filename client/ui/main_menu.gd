extends Control

signal connect_requested(username: String, ip: String)

@onready var username_input: LineEdit = $Panel/VBoxContainer/UsernameInput
@onready var ip_input: LineEdit = $Panel/VBoxContainer/IPInput
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var disconnect_popup: AcceptDialog = $DisconnectPopup

func _ready() -> void:
	# Focus username by default
	username_input.grab_focus()

func show_disconnect_reason(reason: String) -> void:
	if disconnect_popup:
		disconnect_popup.dialog_text = reason
		disconnect_popup.popup()
		status_label.text = "" # Clear status

func _on_connect_button_pressed() -> void:
	var username = username_input.text.strip_edges()
	var ip = ip_input.text.strip_edges()
	
	if username.is_empty():
		status_label.text = "Please enter a username."
		return
	
	if ip.is_empty():
		ip = "127.0.0.1"
	
	status_label.text = "Connecting..."
	emit_signal("connect_requested", username, ip)
