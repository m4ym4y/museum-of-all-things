extends Control

signal start
signal settings

var fade_in_start = Color(0.0, 0.0, 0.0, 1.0)
var fade_in_end = Color(0.0, 0.0, 0.0, 0.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  _on_visibility_changed()
  call_deferred("_start_fade_in")

  if Util.is_web():
    %Quit.visible = false

func _on_visibility_changed():
  if visible:
    $MarginContainer/VBoxContainer/Start.grab_focus()

func _start_fade_in():
  $FadeIn.color = fade_in_start
  $FadeInStage2.color = fade_in_start
  var tween = get_tree().create_tween()
  tween.tween_property($FadeIn, "color", fade_in_end, 1.5)
  tween.tween_property($FadeInStage2, "color", fade_in_end, 1.5)
  tween.set_trans(Tween.TRANS_LINEAR)
  tween.set_ease(Tween.EASE_IN_OUT)

func _on_start_pressed():
  emit_signal("start")

func _on_settings_pressed():
  emit_signal("settings")

func _on_quit_button_pressed():
  get_tree().quit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass
