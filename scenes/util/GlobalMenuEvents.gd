extends Node

signal hide_menu
signal return_to_lobby
signal set_current_room

func emit_hide_menu():
  emit_signal("hide_menu")

func emit_return_to_lobby():
  emit_signal("return_to_lobby")

func emit_set_current_room(room):
  emit_signal("set_current_room", room)
