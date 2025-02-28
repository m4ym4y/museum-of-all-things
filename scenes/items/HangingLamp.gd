extends Node3D

@export var is_managed_light := true
@export var skip_managed_light_direction_test := false

func _ready() -> void:
  if is_managed_light:
    $SpotLight3D.add_to_group('managed_light')
  if skip_managed_light_direction_test:
    $SpotLight3D.add_to_group('managed_light_skip_direction_test')
