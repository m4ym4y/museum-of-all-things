@tool
extends Node3D

@onready var material_black: Material = preload("res://assets/textures/black.tres")
@onready var pole_mesh: Mesh = preload("res://assets/models/railing_pole.obj")

@export var railing_length: float = 4.0

var multimesh_instance: MultiMeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  multimesh_instance = MultiMeshInstance3D.new()
  pole_mesh.surface_set_material(0, material_black)
  var multimesh = MultiMesh.new()
  multimesh.transform_format = MultiMesh.TRANSFORM_3D
  multimesh.instance_count = railing_length + 1
  multimesh.mesh = pole_mesh
  multimesh_instance.multimesh = multimesh
  add_child(multimesh_instance)

  var collision_shape = BoxShape3D.new()
  collision_shape.size = Vector3(railing_length + 0.1, 1.1, 0.1)

  $Railing.scale.x = railing_length + 0.1
  $StaticBody3D/CollisionShape3D.shape = collision_shape

  for i in range(0, railing_length + 1.0, 1.0):
    var transform = Transform3D()
    var x_offset = -railing_length / 2.0 + i
    transform.origin = Vector3(x_offset, 0, 0)

    multimesh.set_instance_transform(i, transform)
