extends Control

signal resume
signal settings
signal return_to_lobby

@onready var vbox = $MarginContainer/VBoxContainer

func _on_visibility_changed():
	if visible:
		vbox.get_node("Resume").grab_focus()

var current_room = "$Lobby"
func set_current_room(room):
	current_room = room
	vbox.get_node("Title").text = current_room.replace("$", "") + " - Paused"
	vbox.get_node("Open").disabled = current_room.begins_with("$")

func _on_resume_pressed():
	emit_signal("resume")

func _on_settings_pressed():
	emit_signal("settings")

func _on_lobby_pressed():
	emit_signal("return_to_lobby")

func _on_open_pressed():
	OS.shell_open("https://en.wikipedia.org/wiki/" + current_room)

func _on_quit_pressed():
	get_tree().quit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass