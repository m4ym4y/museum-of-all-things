@tool
extends MeshInstance3D

@export var no_light: bool = false

func _ready() -> void:
  if no_light:
    $MeshInstance3D.visible = false
    $SpotLight3D.visible = false
