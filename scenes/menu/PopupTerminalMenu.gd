extends Control

signal resume

func _on_terminal_menu_resume():
  if visible:
    call_deferred("emit_signal", "resume")
