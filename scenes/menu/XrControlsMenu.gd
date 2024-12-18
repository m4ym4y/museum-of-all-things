extends Control

signal resume

@onready var vbox = $MarginContainer/VBoxContainer

func _on_back_pressed() -> void:
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
