extends Node3D

func _ready() -> void:
  var viewport_scene = $Viewport2Din3D.get_scene_instance()
  if viewport_scene:
    for line_edit in viewport_scene.find_children("*", "LineEdit"):
      line_edit.focus_entered.connect(_on_line_edit_focus_entered)
      line_edit.focus_exited.connect(_on_line_edit_focus_exited)

func _on_line_edit_focus_entered() -> void:
  if Util.is_xr() and not Util.is_meta_quest():
    $VirtualKeyboard.visible = true

func _on_line_edit_focus_exited() -> void:
  $VirtualKeyboard.visible = false
