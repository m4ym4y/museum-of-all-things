@tool
extends Node3D

@export var mesh_instance: Mesh
@export var material_override: Material
@export var area_size: Vector3 = Vector3(10, 0, 10)
@export var instance_count: int = 100
@export var max_leaves_per_plant: int = 10
@export var max_leaf_scale = 2
@export var min_leaf_scale = 0.25

var multimesh_instance: MultiMeshInstance3D

func _ready() -> void:
  multimesh_instance = MultiMeshInstance3D.new()
  mesh_instance.surface_set_material(0, material_override)
  var multimesh = MultiMesh.new()
  multimesh.transform_format = MultiMesh.TRANSFORM_3D
  multimesh.instance_count = instance_count
  multimesh.mesh = mesh_instance
  multimesh_instance.multimesh = multimesh
  add_child(multimesh_instance)

  var random = RandomNumberGenerator.new()
  random.randomize()

  var last_origin
  var leaves_in_plant

  for i in range(instance_count):
    var transform = Transform3D()

    if last_origin and leaves_in_plant <= max_leaves_per_plant:
      transform.origin = last_origin
      leaves_in_plant += 1
    else:
      leaves_in_plant = 0
      transform.origin = Vector3(
        random.randf_range(-area_size.x / 2, area_size.x / 2),
        random.randf_range(-area_size.y / 2, area_size.y / 2),
        random.randf_range(-area_size.z / 2, area_size.z / 2)
      )
      last_origin = transform.origin

    transform.basis = Basis().rotated(Vector3.UP, random.randf_range(0, TAU))
    transform.basis = transform.basis.rotated(
      Vector3.RIGHT,
      random.randf_range(-PI / 4, PI / 4))

    var scale_factor = random.randf_range(min_leaf_scale, max_leaf_scale)
    transform = transform.scaled(Vector3.ONE * scale_factor)
    transform.origin *= 1 / scale_factor
    multimesh.set_instance_transform(i, transform)
