## Responsive joystick control tool for your 
## Godot mobile games. It triggers input actions
## base on your touch and drag inputs.

@tool
@icon("res://addons/touch_screen_joystick/icon.png")
extends Control
class_name TouchScreenJoystick

## Enable Anti-aliasing for drawing
@export var antialiased : bool = false : 
	set(b):
		antialiased = b
		queue_redraw()

## Deadzone size 
@export_range(0, 9999, 0.1, "hide_slider")
var deadzone : float= 25.0 : 
	set(n):
		deadzone = n
		queue_redraw()

## Radius for drawing the base
## and for max distance of knob from the center
@export_range(0, 9999, 0.1, "hide_slider")
var base_radius : float = 120.0 :
	set(value):
		base_radius = value
		queue_redraw()
## Radius for drawing the knob
@export_range(0, 9999, 0.1, "hide_slider")
var knob_radius : float = 45.0 :
	set(value):
		knob_radius = value
		queue_redraw()



@export_group("Texture Joystick")
## Enable joystick textures
@export var use_textures : bool = false :
	set(value):
		use_textures = value
		queue_redraw()

@export_subgroup("Base")
## Texture for base drawing
@export var base_texture : Texture2D :
	set(value):
		base_texture = value
		queue_redraw()
## Texture scale for base 
@export var base_scale : Vector2 = Vector2.ONE :
	set(value):
		base_scale = value
		queue_redraw()

@export_subgroup("Knob")
## Texture for knob drawing
@export var knob_texture : Texture2D :
	set(value):
		knob_texture = value
		queue_redraw()
## Texture scale for knob
@export var knob_scale : Vector2 = Vector2.ONE :
	set(value):
		knob_scale = value
		queue_redraw()

@export_group("Style")
## Main color
@export var color : Color = Color.WHITE :
	set(value):
		color = value
		queue_redraw()
## Background color
@export var back_color : Color = Color(Color.BLACK, 0.5):
	set(value):
		back_color = value
		queue_redraw()
## Base thickness
@export_range(0, 999, 0.1, "hide_slider")
var thickness := 3.0 :
	set(value):
		thickness = value
		queue_redraw()

@export_group("Input Actions")
## Enable input actions
@export var use_input_actions : bool
## Action for left direction (-X)
@export var action_left : StringName = "ui_left"
## Action for right direction (+X)
@export var action_right : StringName = "ui_right"
## Action for up direction (-Y)
@export var action_up : StringName = "ui_up"
## Action for down direction (+Y)
@export var action_down : StringName = "ui_down"

@export_group("Debug")
## Enable debug draws
@export var show_debug : bool :
	set(value):
		show_debug = value
		queue_redraw()

## Deadzone color for debugging
@export var deadzone_debug_color : Color = Color.RED :
	set(value):
		deadzone_debug_color = value
		queue_redraw()
## Base color for debugging
@export var base_debug_color : Color = Color.GREEN :
	set(value):
		base_debug_color = value
		queue_redraw()

## Emitted when the joystick is being pressed
signal on_press
## Emitted when the joystick is being released
signal on_release
## Emitted when the joystick is being dragged
signal on_drag(factor : float)

## Property for knob draw position
var knob_position : Vector2
## Property for press input
var is_pressing : bool
## Property for index of the input event
## that is currently touching the joystick
var event_index : int = -1

func _draw() -> void:
	if not is_pressing : reset_knob()
	
	if not use_textures:
		draw_default_joystick()
	else:
		draw_texture_joystick()
	
	if show_debug : draw_debug()

## Draws the joystick
func draw_default_joystick() -> void:
	# Base
	draw_circle(size / 2.0, base_radius, back_color)
	draw_circle(size / 2.0, base_radius, color, false, thickness, antialiased)
	
	# Knob
	draw_circle(knob_position, knob_radius, color, true, -1.0, antialiased)

## Draws the textured joystick instead of the default one
func draw_texture_joystick() -> void:
	# Base
	if base_texture:
		var base_size := base_texture.get_size() * base_scale
		draw_texture_rect(base_texture, Rect2(size / 2.0 - (base_size / 2.0), base_size), false)
		
	
	# Knob
	if knob_texture:
		var knob_size := knob_texture.get_size() * knob_scale
		draw_texture_rect(knob_texture, Rect2(knob_position - (knob_size / 2.0), knob_size), false)

## Draws radius of base and deadzone size
func draw_debug() -> void:
	draw_circle(size / 2.0, deadzone, deadzone_debug_color, false, 5.0)
	draw_circle(size / 2.0, base_radius, base_debug_color, false, 5.0)

func _input(event: InputEvent) -> void:
	
	if event is InputEventScreenTouch:
		on_screen_touch(event)
		
	elif event is InputEventScreenDrag:
		on_screen_drag(event)

## Called when the joystick is touched
func on_screen_touch(event : InputEventScreenTouch) -> void:
	var has_point := get_global_rect().has_point(event.position)
	
	if event.pressed and event_index == -1 and has_point:
		event_index = event.index
		touch_knob(event.position, event.index)
	else:
		release_knob(event.index)
		
	

## Called when the joystick is pressed and 
## moves the knob to the current touch position
func touch_knob(pos : Vector2, index : int) -> void:
	if index == event_index: 
		move_knob(pos)
		is_pressing = true
		on_press.emit()
		get_viewport().set_input_as_handled()

## Called when the joystick is released 
## and resets then input actions
func release_knob(index : int) -> void:
	if index == event_index:
		reset_actions()
		reset_knob()
		event_index = -1
		is_pressing = false
		on_release.emit()
		get_viewport().set_input_as_handled()

## Called when the joystick is dragged
func on_screen_drag(event : InputEventScreenDrag) -> void:
	var center := size / 2.0
	var dist := center.distance_to(knob_position)
	
	if event.index == event_index and is_pressing:
		move_knob(event.position)
		get_viewport().set_input_as_handled()
		on_drag.emit(get_factor())


## Moves the knob position relative to the current touch position
func move_knob(event_pos : Vector2) -> void:
	var center := size / 2.0
	var touch_pos := (event_pos - global_position) / scale
	var distance := touch_pos.distance_to(center)
	var angle := center.angle_to_point(touch_pos)
	
	if distance < base_radius:
		knob_position = touch_pos
	else:
		knob_position.x = center.x + cos(angle) * base_radius
		knob_position.y = center.y + sin(angle) * base_radius
	
	if distance > deadzone:
		trigger_actions()
	else:
		reset_actions()
	
	queue_redraw()

## Triggers all the left, right, up, and down actions 
## based on the direction of the knob
func trigger_actions() -> void:
	if not use_input_actions: return
	
	var direction := get_direction().normalized()
	
	if direction.x < 0.0:
		Input.action_release(action_right)
		Input.action_press(action_left, -direction.x)
	elif direction.x > 0.0:
		Input.action_release(action_left)
		Input.action_press(action_right, direction.x)
	
	if direction.y < 0.0:
		Input.action_release(action_down)
		Input.action_press(action_up, -direction.y)
	elif direction.y > 0.0:
		Input.action_release(action_up)
		Input.action_press(action_down, direction.y)


## Resets all the input actions
func reset_actions() -> void:
	Input.action_release(action_left)
	Input.action_release(action_right)
	Input.action_release(action_up)
	Input.action_release(action_down)
	

## Returns a direction vector from the center of 
## the joystick to the knob position
func get_direction() -> Vector2:
	var center := size / 2.0
	var direction := center.direction_to(knob_position)
	return direction

## Returns the distance between the center 
## to the knob position
func get_distance() -> float:
	var center := size / 2.0
	var distance := center.distance_to(knob_position)
	
	return distance

## Returns the angle in radians between the 
## center position to the knob position
func get_angle() -> float:
	var center := size / 2.0
	var angle := center.angle_to_point(knob_position)
	return angle

## Returns a value from 0 to 1 based how far the 
## knob position is from the center
func get_factor() -> float:
	var center := size / 2.0
	var distance := center.distance_to(knob_position)
	return distance / base_radius

## Returns true if the center to knob distance
## is greater than the deadzone size
func is_in_deadzone() -> bool:
	var center := size / 2.0
	var distance := center.distance_to(knob_position)
	return distance < deadzone

## Resets the knob position the center
func reset_knob() -> void:
	knob_position = size / 2.0
	queue_redraw()
