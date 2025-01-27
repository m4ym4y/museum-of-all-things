extends CharacterBody3D

var gravity = -30
var crouch_move_speed = 4
var mouse_sensitivity = 0.002
var joy_sensitivity = 0.025
var joy_deadzone = 0.05
@export var jump_impulse = 13

var starting_height
var crouching_height
var crouch_time = 0.4
var crouch_speed
var _enabled = false

var _joy_right_x = JOY_AXIS_RIGHT_X
var _joy_right_y = JOY_AXIS_RIGHT_Y

@onready var camera = get_node("Pivot/Camera3D")
@onready var _footsteps = {
  "hard": $FootstepsHard,
  "soft": $FootstepsSoft
}

var _default_floor_type = "hard"
var _floor_material_map = {
  11: "soft", # carpet
}

@export var smooth_movement = false
@export var dampening = 0.01
@export var max_speed = 8

func _ready():
  # some strange issue w joystick bindings on linux
  if OS.get_name() == "Linux":
    if OS.get_distribution_name() == "Arch Linux":
      _joy_right_x += 1
      _joy_right_y += 1

  starting_height = $Pivot.get_position().y
  crouching_height = starting_height / 3
  crouch_speed = (starting_height - crouching_height) / crouch_time

# set grid so we can read floor type on it
var _grid
func set_grid(grid):
  _grid = grid

func pause():
  _enabled = false

func start():
  _enabled = true

func get_input_dir():
  var input_dir = Vector3()
  if Input.is_action_pressed("move_forward"):
    input_dir -= global_transform.basis.z
  if Input.is_action_pressed("move_back"):
    input_dir += global_transform.basis.z
  if Input.is_action_pressed("strafe_left"):
    input_dir -= global_transform.basis.x
  if Input.is_action_pressed("strafe_right"):
    input_dir += global_transform.basis.x
  return input_dir.normalized()

var camera_v = Vector2.ZERO
func _unhandled_input(event):
  if not _enabled:
    return

  var is_mouse = event is InputEventMouseMotion
  if is_mouse and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
    var delta_x = -event.relative.x * mouse_sensitivity
    var delta_y = -event.relative.y * mouse_sensitivity

    if not smooth_movement:
      rotate_y(delta_x)
      $Pivot.rotate_x(delta_y)
      $Pivot.rotation.x = clamp($Pivot.rotation.x, -1.2, 1.2)
    else:
      camera_v += Vector2(
        clamp(delta_y, -dampening, dampening),
        clamp(delta_x, -dampening, dampening)
      )

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
  if not _enabled:
    return

  velocity.y += gravity * delta

  var fully_crouched = $Pivot.get_position().y <= crouching_height
  var fully_standing = $Pivot.get_position().y >= starting_height
  var speed = max_speed if fully_standing else crouch_move_speed
  var input = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
  var desired_velocity = transform.basis * Vector3(input.x, 0, input.y) * speed

  velocity.x = desired_velocity.x
  velocity.z = desired_velocity.z
  set_up_direction(Vector3.UP)
  set_floor_stop_on_slope_enabled(true)
  move_and_slide()

  #var delta_vec = Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
  var delta_vec = Vector2(-Input.get_joy_axis(0, _joy_right_x), -Input.get_joy_axis(0, _joy_right_y))
  if delta_vec.length() > joy_deadzone:
    rotate_y(delta_vec.x * joy_sensitivity)
    $Pivot.rotate_x(delta_vec.y * joy_sensitivity)
    $Pivot.rotation.x = clamp($Pivot.rotation.x, -1.2, 1.2)

  if smooth_movement:
    rotate_y(camera_v.y)
    $Pivot.rotate_x(camera_v.x)
    $Pivot.rotation.x = clamp($Pivot.rotation.x, -1.2, 1.2)
    camera_v *= 0.95

  _play_footsteps()

  if Input.is_action_pressed("jump") and is_on_floor():
    velocity.y = jump_impulse
    pass

  if Input.is_action_pressed("crouch") and not fully_crouched:
    $Pivot.global_translate(Vector3(0, -crouch_speed * delta, 0))
  elif not Input.is_action_pressed("crouch") and not fully_standing:
    $Pivot.global_translate(Vector3(0, crouch_speed * delta, 0))

  if Input.is_action_pressed("interact"):
    var collider = $Pivot/Camera3D/RayCast3D.get_collider()
    if collider and collider.has_method("interact"):
      collider.interact()

func _play_footsteps():
  if not _grid:
    return

  var flat_velocity = Vector2(velocity.x, velocity.z).length()

  if is_on_floor() and flat_velocity > 0:
    var floor_cell = Util.worldToGrid(position) - Vector3.UP
    var floor_cell_type = _grid.get_cell_item(floor_cell)
    var step_type = _floor_material_map.get(
      floor_cell_type,
      _default_floor_type
    )

    for step in _footsteps.keys():
      if step == step_type:
        _footsteps[step].pitch_scale = flat_velocity / max_speed
        if not _footsteps[step].playing:
          _footsteps[step].play()
      else:
        _footsteps[step].stop()
  else:
    for step in _footsteps.keys():
      _footsteps[step].stop()
