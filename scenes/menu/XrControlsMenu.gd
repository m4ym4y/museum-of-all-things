extends Control

signal resume

@onready var vbox = $MarginContainer/VBoxContainer
var _default_settings

func _ready():
  GlobalMenuEvents.load_xr_settings.connect(_load_xr_settings)

func _load_xr_settings():
  _default_settings = _create_settings_obj()
  var settings = _load_settings()
  _apply_settings(settings)

func _apply_settings(settings):
  if not settings:
    return
  if settings.has("movement_speed"):
    vbox.get_node("MovementOptions/MovementSpeed").value = settings.movement_speed
  if settings.has("movement_style"):
    if settings.movement_style == "teleportation":
      _on_teleportation_pressed()
    elif settings.movement_style == "direct":
      _on_direct_movement_pressed()
  if settings.has("rotation_increment"):
    vbox.get_node("RotationOptions/RotationIncrement").value = settings.rotation_increment
  if settings.has("smooth_rotation"):
    vbox.get_node("RotationOptions/SmoothRotation").button_pressed = settings.smooth_rotation

func _load_settings():
  var file = FileAccess.open("user://vr_settings.json", FileAccess.READ)
  if not file:
    return null
  var json_text = file.get_as_text()
  file.close()
  return JSON.parse_string(json_text)

func _create_settings_obj():
  return {
    "movement_style": "teleportation" if vbox.get_node("MovementOptions/Styles/Teleportation").disabled else "direct",
    "movement_speed": vbox.get_node("MovementOptions/MovementSpeed").value,
    "rotation_increment": vbox.get_node("RotationOptions/RotationIncrement").value,
    "smooth_rotation": vbox.get_node("RotationOptions/SmoothRotation").button_pressed
  }

func _save_settings():
  var s = _create_settings_obj()
  var json_text = JSON.stringify(s)
  var file = FileAccess.open("user://vr_settings.json", FileAccess.WRITE)
  file.store_string(json_text)
  file.close()

func _on_back_pressed() -> void:
  _save_settings()
  emit_signal("resume")

func _on_movement_speed_value_changed(value: float) -> void:
  vbox.get_node("MovementOptions/MovementSpeedValue").text = str(value)
  GlobalMenuEvents.emit_set_movement_speed(value)

func _on_teleportation_pressed() -> void:
  GlobalMenuEvents.emit_set_xr_movement_style("teleportation")
  vbox.get_node("MovementOptions/Styles/Teleportation").disabled = true
  vbox.get_node("MovementOptions/Styles/DirectMovement").disabled = false
  vbox.get_node("MovementOptions/MovementSpeed").editable = false

func _on_direct_movement_pressed() -> void:
  GlobalMenuEvents.emit_set_xr_movement_style("direct")
  vbox.get_node("MovementOptions/Styles/Teleportation").disabled = false
  vbox.get_node("MovementOptions/Styles/DirectMovement").disabled = true
  vbox.get_node("MovementOptions/MovementSpeed").editable = true

func _on_rotation_increment_value_changed(value: float) -> void:
  vbox.get_node("RotationOptions/RotationIncrementValue").text = str(value)
  GlobalMenuEvents.emit_set_xr_rotation_increment(value)

func _on_smooth_rotation_toggled(toggled_on: bool) -> void:
  vbox.get_node("RotationOptions/RotationIncrement").editable = not toggled_on
  GlobalMenuEvents.emit_set_xr_smooth_rotation(toggled_on)

func _on_restore_default_pressed() -> void:
  _apply_settings(_default_settings)
