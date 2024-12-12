extends CharacterBody3D

var gravity = -30
var crouch_move_speed = 4
var mouse_sensitivity = 0.002
var joy_sensitivity = 0.025
@export var jump_impulse = 13

var starting_height
var crouching_height
var crouch_time = 0.4
var crouch_speed
var _enabled = false

@onready var camera = get_node("Pivot/Camera3D")

@export var smooth_movement = false
@export var dampening = 0.01
@export var max_speed = 8

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	starting_height = $Pivot.get_position().y
	crouching_height = starting_height / 3
	crouch_speed = (starting_height - crouching_height) / crouch_time

func init():
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
	var delta_vec = Vector2(-Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y), -Input.get_joy_axis(0, 4))
	if delta_vec.length() > 0:
		rotate_y(delta_vec.x * joy_sensitivity)
		$Pivot.rotate_x(delta_vec.y * joy_sensitivity)
		$Pivot.rotation.x = clamp($Pivot.rotation.x, -1.2, 1.2)

	if smooth_movement:
		rotate_y(camera_v.y)
		$Pivot.rotate_x(camera_v.x)
		$Pivot.rotation.x = clamp($Pivot.rotation.x, -1.2, 1.2)
		camera_v *= 0.95

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
