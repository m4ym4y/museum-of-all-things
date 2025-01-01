extends Control

signal resume
var _xr = Util.is_xr()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  if _xr:
    var vbox = $MarginContainer/VBoxContainer
    vbox.get_node("FPSOptions").visible = false
    vbox.get_node("ReflectionOptions").visible = false

func _on_visibility_changed():
  if visible and is_inside_tree():
    _load_settings()
    $MarginContainer/VBoxContainer/MainOptions/Back.grab_focus()

func _load_settings():
  var vbox = $MarginContainer/VBoxContainer
  var e = GraphicsManager.get_env()

  vbox.get_node("FPSOptions/MaxFPS").value = GraphicsManager.fps_limit
  vbox.get_node("FPSOptions/LimitFPS").button_pressed = GraphicsManager.limit_fps
  vbox.get_node("ReflectionOptions/ReflectionQuality").value = e.ssr_max_steps
  vbox.get_node("ReflectionOptions/EnableReflections").button_pressed = e.ssr_enabled
  vbox.get_node("FogOptions/EnableFog").button_pressed = e.fog_enabled
  _refresh_cache_label()

func _on_restore_pressed():
  GraphicsManager.restore_default_settings()
  _load_settings()

func _on_resume_pressed():
  GraphicsManager.save_settings()
  emit_signal("resume")

func _on_reflection_quality_value_changed(value: float):
  GraphicsManager.get_env().ssr_max_steps = int(value)
  $MarginContainer/VBoxContainer/ReflectionOptions/ReflectionQualityValue.text = str(int(value))

func _on_enable_reflections_toggled(toggled_on: bool):
  GraphicsManager.get_env().ssr_enabled = toggled_on

func _on_max_fps_value_changed(value: float):
  GraphicsManager.set_fps_limit(value)
  $MarginContainer/VBoxContainer/FPSOptions/MaxFPSValue.text = str(int(value))

func _on_limit_fps_toggled(toggled_on: bool):
  GraphicsManager.enable_fps_limit(toggled_on)

func _on_enable_fog_toggled(toggled_on: bool):
  GraphicsManager.get_env().fog_enabled = toggled_on

func _on_clear_cache_pressed():
  # this is going to be big so we stream it
  var dir = DirAccess.open("user://cache")
  dir.list_dir_begin()

  while true:
    var file = dir.get_next()
    if not file:
      break
    dir.remove(file)

  _refresh_cache_label()

func _refresh_cache_label():
  var count = 0
  var dir = DirAccess.open("user://cache")
  dir.list_dir_begin()
  while dir.get_next():
    count += 1
  $MarginContainer/VBoxContainer/CacheOptions/CacheLabel.text = "Cache (%s items)" % count

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass


func _on_pause_menu_settings() -> void:
  pass # Replace with function body.
