extends Node

signal ui_cancel_pressed
signal ui_accept_pressed
signal hide_menu
signal return_to_lobby
signal _on_fullscreen_toggled(enabled: bool)
signal set_current_room
signal set_xr_movement_style
signal set_movement_speed
signal set_xr_rotation_increment
signal set_xr_smooth_rotation
signal load_xr_settings
signal open_terminal_menu
signal terminal_result_ready(error: bool, page: String)
signal set_custom_door(title: String)
signal reset_custom_door
signal set_invert_y(enabled: bool)
signal set_mouse_sensitivity(factor: float)
signal set_joypad_deadzone(value: float)
signal set_language(language: String)

func emit_ui_cancel_pressed():
  emit_signal("ui_cancel_pressed")

func emit_ui_accept_pressed():
  emit_signal("ui_accept_pressed")

func emit_hide_menu():
  emit_signal("hide_menu")

func emit_return_to_lobby():
  emit_signal("return_to_lobby")

func emit_set_current_room(room):
  emit_signal("set_current_room", room)

func emit_on_fullscreen_toggled(enabled):
  emit_signal("_on_fullscreen_toggled", enabled)

func emit_set_xr_movement_style(style):
  emit_signal("set_xr_movement_style", style)

func emit_set_movement_speed(speed):
  emit_signal("set_movement_speed", speed)

func emit_set_xr_rotation_increment(increment):
  emit_signal("set_xr_rotation_increment", increment)

func emit_set_xr_smooth_rotation(enabled):
  emit_signal("set_xr_smooth_rotation", enabled)

func emit_load_xr_settings():
  emit_signal("load_xr_settings")

func emit_open_terminal_menu():
  emit_signal("open_terminal_menu")

func emit_terminal_result_ready(error: bool, page: String):
  emit_signal("terminal_result_ready", error, page)

func emit_set_custom_door(title: String):
  emit_signal("set_custom_door", title)

func emit_reset_custom_door():
  emit_signal("reset_custom_door")

func emit_set_invert_y(enabled: bool):
  emit_signal("set_invert_y", enabled)

func emit_set_mouse_sensitivity(factor: float):
  emit_signal("set_mouse_sensitivity", factor)

func emit_set_joypad_deadzone(value: float):
  emit_signal("set_joypad_deadzone", value)

func emit_set_language(language: String):
  emit_signal("set_language", language)
