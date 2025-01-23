extends Node3D

const collision_layer := 0b0000_0000_0101_0000_0000_0000_0000_0000

func _physics_process(delta: float) -> void:
  global_rotation.z = 0

func enable_collision():
  $Viewport2Din3D.set_collision_layer(collision_layer)

func disable_collision():
  $Viewport2Din3D.set_collision_layer(0)
