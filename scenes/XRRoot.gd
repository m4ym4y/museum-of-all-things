extends Node3D

@onready var left_controller = $XROrigin3D/XRController3D_left
@onready var right_controller = $XROrigin3D/XRController3D_right

"""
signal set_xr_movement_style
signal set_movement_speed
signal set_xr_rotation_increment
signal set_xr_smooth_rotation
"""

const TRIGGER_TELEPORT_ACTION = "trigger_click"
const THUMBSTICK_TELEPORT_ACTION = "thumbstick_up"

const THUMBSTICK_TELEPORT_PRESSED_THRESHOLD := 0.8
const THUMBSTICK_TELEPORT_RELEASED_THRESHOLD := 0.4

var _thumbstick_teleport_pressed := false

func _ready():
  if Util.is_openxr():
    var interface = XRServer.find_interface("OpenXR")
    print("initializing XR interface OpenXR...")
    if interface and interface.initialize():
      print("initialized")
      # turn the main viewport into an ARVR viewport:
      get_viewport().use_xr = true

      # turn off v-sync
      DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

      # put our physics in sync with our expected frame rate:
      Engine.physics_ticks_per_second = 90
    else:
      $FailedVrAccept.popup()
      get_tree().paused = true
      return

  if Util.is_webxr():
    var interface = XRServer.find_interface("WebXR")

    # WebXR is less powerful than when running natively in OpenXR, so target 72 FPS.
    interface.set_display_refresh_rate(72)
    Engine.physics_ticks_per_second = 72

    XRToolsUserSettings.webxr_primary_changed.connect(_on_webxr_primary_changed)
    _on_webxr_primary_changed(XRToolsUserSettings.get_real_webxr_primary())

  # Things we need for both OpenXR and WebXR.
  GlobalMenuEvents.hide_menu.connect(_hide_menu)
  GlobalMenuEvents.set_xr_movement_style.connect(_set_xr_movement_style)
  GlobalMenuEvents.set_movement_speed.connect(_set_xr_movement_speed)
  GlobalMenuEvents.set_xr_rotation_increment.connect(_set_xr_rotation_increment)
  GlobalMenuEvents.set_xr_smooth_rotation.connect(_set_xr_smooth_rotation)
  GlobalMenuEvents.emit_load_xr_settings()
  left_controller.get_node("FunctionPointer/Laser").visibility_changed.connect(_laser_visible_changed)

func _failed_vr_accept_confirmed():
  get_tree().quit()

func _on_webxr_primary_changed(webxr_primary: int):
  # Default to thumbstick.
  if webxr_primary == 0:
    webxr_primary = XRToolsUserSettings.WebXRPrimary.THUMBSTICK

  var action_name = XRToolsUserSettings.get_webxr_primary_action(webxr_primary)
  %XRToolsMovementDirect.input_action = action_name
  %XRToolsMovementTurn.input_action = action_name

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
  $XROrigin3D/XRToolsPlayerBody/FootstepPlayer.set_on_floor($XROrigin3D/XRToolsPlayerBody.is_on_floor())
  if right_controller and right_controller.is_button_pressed("by_button") and not by_button_pressed:
    by_button_pressed = true
    if not menu_active:
      _show_menu()
    else:
      _hide_menu()
  elif right_controller and not right_controller.is_button_pressed("by_button") and by_button_pressed:
    by_button_pressed = false

func _on_xr_controller_3d_left_input_vector2_changed(name: String, value: Vector2) -> void:
  var xr_tracker: XRPositionalTracker = XRServer.get_tracker(left_controller.tracker)

  if _thumbstick_teleport_pressed:
    if value.length() < THUMBSTICK_TELEPORT_RELEASED_THRESHOLD:
      _thumbstick_teleport_pressed = false
      xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, false)

  else:
    if value.y > THUMBSTICK_TELEPORT_PRESSED_THRESHOLD and not left_controller.is_button_pressed(TRIGGER_TELEPORT_ACTION):
      _thumbstick_teleport_pressed = true
      xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, true)

func _on_xr_controller_3d_left_button_pressed(name: String) -> void:
  if not _thumbstick_teleport_pressed and name == TRIGGER_TELEPORT_ACTION:
    var xr_tracker: XRPositionalTracker = XRServer.get_tracker(left_controller.tracker)
    xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, true)

func _on_xr_controller_3d_left_button_released(name: String) -> void:
  if not _thumbstick_teleport_pressed and name == TRIGGER_TELEPORT_ACTION:
    var xr_tracker: XRPositionalTracker = XRServer.get_tracker(left_controller.tracker)
    xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, false)
