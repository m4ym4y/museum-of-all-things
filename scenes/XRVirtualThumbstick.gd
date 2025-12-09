extends Node3D

const MAX_DISTANCE := 0.08
const DEADZONE := 0.01

@onready var pos_mesh: MeshInstance3D = $PosMesh

var _xr_controller: XRController3D
var _xr_tracker: XRControllerTracker
var _action: String
var _axis_mask: Vector3

func setup_virtual_thumbstick(xr_controller: XRController3D, action: String, axis_mask := Vector3(1.0, 1.0, 1.0)) -> void:
  _xr_controller = xr_controller
  _xr_tracker = XRServer.get_tracker(_xr_controller.tracker)
  _action = action
  _axis_mask = axis_mask * Vector3(1.0, 0.0, 1.0)

  var t: Transform3D = _get_controller_transform()

  # Flatten the Y axis, so it's level with the ground.
  var z: Vector3 = (t.basis.z * Vector3(1.0, 0.0, 1.0)).normalized()
  var y: Vector3 = Vector3.UP
  var x: Vector3 = y.cross(z)
  t.basis = Basis(x, y, z)

  global_transform = t

func release_virtual_thumbstick() -> void:
  _xr_tracker.set_input(_action, Vector2())

func _get_controller_transform() -> Transform3D:
  return _xr_controller.global_transform

func _process(_delta: float) -> void:
  pos_mesh.global_position = _xr_controller.global_position

  var v: Vector3 = pos_mesh.position * _axis_mask
  if v.length() > MAX_DISTANCE:
    v = v.normalized() * MAX_DISTANCE
  pos_mesh.position = v

  if v.length() > DEADZONE:
    v = v / MAX_DISTANCE
    _xr_tracker.set_input(_action, Vector2(v.x, -v.z))
  else:
    _xr_tracker.set_input(_action, Vector2(0.0, 0.0))
