extends Node3D

@export var light: bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  if not light:
    $OmniLight3D.queue_free()
