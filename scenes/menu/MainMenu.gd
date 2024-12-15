extends Control

signal start
signal settings

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  _on_visibility_changed()

func _on_visibility_changed():
  if visible:
    $MarginContainer/VBoxContainer/Start.grab_focus()

func _on_start_pressed():
  emit_signal("start")

func _on_settings_pressed():
  emit_signal("settings")

func _on_quit_button_pressed():
  get_tree().quit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass
