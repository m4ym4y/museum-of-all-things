extends Control

signal resume
signal settings
signal return_to_lobby

@onready var vbox = $MarginContainer/VBoxContainer
@onready var _xr = Util.is_xr()

func _on_visibility_changed():
  if visible and vbox:
    vbox.get_node("Resume").grab_focus()

func _ready():
  GlobalMenuEvents.set_current_room.connect(set_current_room)
  set_current_room(current_room)

  # opening page in a browser outside VR is confusing
  if _xr:
    $MarginContainer/VBoxContainer/Open.visible = false

var current_room = "$Lobby"
func set_current_room(room):
  current_room = room
  vbox.get_node("Title").text = current_room.replace("$", "") + (" - Paused" if not _xr else "")
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

func _on_ask_quit_pressed():
  $MarginContainer/VBoxContainer.visible = false
  $MarginContainer/QuitContainer.visible = true
  $MarginContainer/QuitContainer/Quit.grab_focus()

func _on_cancel_quit_pressed():
  $MarginContainer/QuitContainer.visible = false
  $MarginContainer/VBoxContainer.visible = true
  $MarginContainer/VBoxContainer/Resume.grab_focus()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass
