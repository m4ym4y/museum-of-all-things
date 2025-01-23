extends Node3D

@onready var left_controller = $XROrigin3D/XRController3D_left
@onready var right_controller = $XROrigin3D/XRController3D_right

"""
signal set_xr_movement_style
signal set_movement_speed
signal set_xr_rotation_increment
signal set_xr_smooth_rotation
"""

func _ready():
  var interface = XRServer.find_interface("OpenXR")
  print("initializing XR interface OpenXR...")
  if interface and interface.initialize():
    print("initialized")
    # turn the main viewport into an ARVR viewport:
    get_viewport().use_xr = true

    # turn off v-sync
    # OS.vsync_enabled = false

    # put our physics in sync with our expected frame rate:
    Engine.physics_ticks_per_second = 90

    GlobalMenuEvents.hide_menu.connect(_hide_menu)
    GlobalMenuEvents.set_xr_movement_style.connect(_set_xr_movement_style)
    GlobalMenuEvents.set_movement_speed.connect(_set_xr_movement_speed)
    GlobalMenuEvents.set_xr_rotation_increment.connect(_set_xr_rotation_increment)
    GlobalMenuEvents.set_xr_smooth_rotation.connect(_set_xr_smooth_rotation)
    GlobalMenuEvents.emit_load_xr_settings()
    left_controller.get_node("FunctionPointer/Laser").visibility_changed.connect(_laser_visible_changed)

var menu_active = false
var by_button_pressed = false
var movement_style = "teleportation"

func _set_xr_movement_style(style):
  movement_style = style
  if style == "teleportation":
    left_controller.get_node("FunctionTeleport").enabled = not menu_active
    left_controller.get_node("XRToolsMovementDirect").enabled = false
  elif style == "direct":
    left_controller.get_node("FunctionTeleport").enabled = false
    left_controller.get_node("XRToolsMovementDirect").enabled = true

func _set_xr_movement_speed(speed):
  left_controller.get_node("XRToolsMovementDirect").max_speed = speed

func _set_xr_rotation_increment(increment):
  right_controller.get_node("XRToolsMovementTurn").step_turn_angle = increment

func _set_xr_smooth_rotation(enabled):
  right_controller.get_node("XRToolsMovementTurn").turn_mode = XRToolsMovementTurn.TurnMode.SMOOTH if enabled else XRToolsMovementTurn.TurnMode.SNAP

func _laser_visible_changed():
  if movement_style == "teleportation":
    left_controller.get_node("FunctionTeleport").enabled = not left_controller.get_node("FunctionPointer/Laser").visible

func _hide_menu():
  menu_active = false
  right_controller.get_node("XrMenu").disable_collision()
  right_controller.get_node("XrMenu").visible = false

func _show_menu():
  menu_active = true
  right_controller.get_node("XrMenu").enable_collision()
  right_controller.get_node("XrMenu").visible = true

func _physics_process(delta: float) -> void:
  if right_controller and right_controller.is_button_pressed("by_button") and not by_button_pressed:
    by_button_pressed = true
    if not menu_active:
      _show_menu()
    else:
      _hide_menu()
  elif right_controller and not right_controller.is_button_pressed("by_button") and by_button_pressed:
    by_button_pressed = false
