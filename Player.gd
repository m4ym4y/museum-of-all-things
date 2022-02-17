extends KinematicBody

var gravity = -30
var max_speed = 8
var crouch_move_speed = 4
var mouse_sensitivity = 0.002
export var jump_impulse = 13

var velocity = Vector3()

var starting_height
var crouching_height
var crouch_time = 0.4
var crouch_speed

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	starting_height = $Pivot.get_translation().y
	crouching_height = starting_height / 3
	crouch_speed = (starting_height - crouching_height) / crouch_time

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

func _unhandled_input(event):
	var is_mouse = event is InputEventMouseMotion
	if is_mouse and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		$Pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		$Pivot.rotation.x = clamp($Pivot.rotation.x, -1.2, 1.2)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	velocity.y += gravity * delta

	var fully_crouched = $Pivot.get_translation().y <= crouching_height
	var fully_standing = $Pivot.get_translation().y >= starting_height
	var speed = max_speed if fully_standing else crouch_move_speed
	var desired_velocity = get_input_dir() * speed

	velocity.x = desired_velocity.x
	velocity.z = desired_velocity.z
	velocity = move_and_slide(velocity, Vector3.UP, true)

	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = jump_impulse
	
	if Input.is_action_pressed("crouch") and not fully_crouched:
		$Pivot.global_translate(Vector3(0, -crouch_speed * delta, 0))
	elif not Input.is_action_pressed("crouch") and not fully_standing:
		$Pivot.global_translate(Vector3(0, crouch_speed * delta, 0))
