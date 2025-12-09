extends Node3D

const XRVirtualThumbstickScene = preload("res://scenes/XRVirtualThumbstick.tscn")

@onready var xr_origin = $XROrigin3D
@onready var player_body = $XROrigin3D/XRToolsPlayerBody
@onready var left_controller = $XROrigin3D/XRController3D_left
@onready var left_controller_hand = $XROrigin3D/XRController3D_left/LeftHand
@onready var right_controller = $XROrigin3D/XRController3D_right
@onready var right_controller_hand = $XROrigin3D/XRController3D_right/RightHand
@onready var left_hand_tracking = $XROrigin3D/HandTrackingLeft
@onready var right_hand_tracking = $XROrigin3D/HandTrackingRight
@onready var menu_pivot = $XROrigin3D/MenuPivot
@onready var menu_pivot_timer: Timer = $MenuPivotTimer
@onready var menu_icon = $XROrigin3D/HandTrackingLeft/MenuIcon
@onready var camera = $XROrigin3D/XRCamera3D
@onready var xr_menu = $XROrigin3D/MenuPivot/XrMenu

"""
signal set_xr_movement_style
signal set_movement_speed
signal set_xr_rotation_increment
signal set_xr_smooth_rotation
"""

const TRIGGER_TELEPORT_ACTION = "trigger_click"
const THUMBSTICK_TELEPORT_ACTION = "thumbstick_up"
const REAL_ROTATION_ACTION = "primary"
const VIRTUAL_ROTATION_ACTION = "virtual_rotation"
const TRIGGER_POINTER_ACTION = "trigger_click"
const PINCH_POINTER_ACTION = "pinch"

const PRESSED_THRESHOLD := 0.8
const RELEASED_THRESHOLD := 0.6

var _thumbstick_teleport_pressed := false
var _is_menu_gesture_ready := false

var _left_hand_pinching := false
var _right_hand_pinching := false

var _left_virtual_thumbstick
var _right_virtual_thumbstick

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

      # Update hand tracking for initial state.
      _on_hand_tracking_left_tracking_changed(left_hand_tracking.get_has_tracking_data())
      _on_hand_tracking_right_tracking_changed(right_hand_tracking.get_has_tracking_data())
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

func _is_openxr_hand_tracking_aim_enabled() -> bool:
  if Util.is_openxr():
    var hand_tracking_aim_extension = Engine.get_singleton("OpenXRFbHandTrackingAimExtensionWrapper")
    return hand_tracking_aim_extension and hand_tracking_aim_extension.is_enabled()
  return false

func _on_webxr_primary_changed(webxr_primary: int):
  # Default to thumbstick.
  if webxr_primary == 0:
    webxr_primary = XRToolsUserSettings.WebXRPrimary.THUMBSTICK

  var action_name = XRToolsUserSettings.get_webxr_primary_action(webxr_primary)
  %XRToolsMovementDirect.input_action = action_name
  %XRToolsMovementTurn.input_action = action_name

var menu_active = false
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
  xr_menu.disable_collision()
  xr_menu.visible = false

func _show_menu():
  menu_active = true
  xr_menu.enable_collision()
  xr_menu.visible = true
  menu_pivot.position = camera.position * Vector3(1.0, 0.0, 1.0)
  menu_pivot.basis = _get_menu_pivot_basis()

func _get_menu_pivot_basis() -> Basis:
  var z: Vector3 = (camera.basis.z * Vector3(1.0, 0.0, 1.0)).normalized()
  var y: Vector3 = Vector3.UP
  var x: Vector3 = y.cross(z)
  return Basis(x, y, z)

func _process(_delta: float) -> void:
  if not _is_openxr_hand_tracking_aim_enabled():
    var vector_to_camera: Vector3 = (camera.position - left_hand_tracking.position).normalized()
    if vector_to_camera.dot(left_hand_tracking.basis.z) > 0.8:
      _is_menu_gesture_ready = true
      menu_icon.visible = true
    else:
      _is_menu_gesture_ready = false
      menu_icon.visible = false

  if menu_active:
    var desired_basis := _get_menu_pivot_basis()
    if menu_pivot.basis.z.dot(desired_basis.z) < 0.9:
      if menu_pivot_timer.is_stopped():
        menu_pivot_timer.start()
    else:
      menu_pivot_timer.stop()

func _on_menu_pivot_timer_timeout() -> void:
  var pivot_tween = get_tree().create_tween()
  var desired_basis := _get_menu_pivot_basis()
  pivot_tween.tween_method(self._tween_menu_pivot_basis, menu_pivot.basis.get_rotation_quaternion(), desired_basis.get_rotation_quaternion(), 0.9) \
    .set_trans(Tween.TRANS_EXPO) \
    .set_ease(Tween.EASE_OUT)

func _tween_menu_pivot_basis(quat: Quaternion) -> void:
  menu_pivot.basis = Basis(quat)

func _physics_process(delta: float) -> void:
  $XROrigin3D/XRToolsPlayerBody/FootstepPlayer.set_on_floor($XROrigin3D/XRToolsPlayerBody.is_on_floor())

func _toggle_menu() -> void:
  if not menu_active:
    _show_menu()
  else:
    _hide_menu()

func _on_xr_controller_3d_left_input_vector2_changed(name: String, value: Vector2) -> void:
  var xr_tracker: XRPositionalTracker = XRServer.get_tracker(left_controller.tracker)

  if _thumbstick_teleport_pressed:
    if value.length() < RELEASED_THRESHOLD:
      _thumbstick_teleport_pressed = false
      xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, false)

  else:
    if value.y > PRESSED_THRESHOLD and not left_controller.is_button_pressed(TRIGGER_TELEPORT_ACTION):
      _thumbstick_teleport_pressed = true
      xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, true)

func _on_xr_controller_3d_left_button_pressed(name: String) -> void:
  if not _thumbstick_teleport_pressed and name == TRIGGER_TELEPORT_ACTION:
    var xr_tracker: XRPositionalTracker = XRServer.get_tracker(left_controller.tracker)
    xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, true)
  elif name in ["menu_button", "by_button"]:
    _toggle_menu()

func _on_xr_controller_3d_left_button_released(name: String) -> void:
  if not _thumbstick_teleport_pressed and name == TRIGGER_TELEPORT_ACTION:
    var xr_tracker: XRPositionalTracker = XRServer.get_tracker(left_controller.tracker)
    xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, false)

func _on_xr_controller_3d_right_button_pressed(name: String) -> void:
  if name == "by_button":
    _toggle_menu()

func _on_xr_controller_3d_right_button_released(name: String) -> void:
  pass

func _on_xr_controller_3d_left_input_float_changed(name: String, value: float) -> void:
  if name == "pinch":
    var xr_tracker: XRPositionalTracker = XRServer.get_tracker(left_controller.tracker)
    if _left_hand_pinching:
      if value < RELEASED_THRESHOLD:
        _left_hand_pinching = false
        xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, false)
        xr_tracker.set_input(PINCH_POINTER_ACTION, false)

        if _left_virtual_thumbstick:
          _left_virtual_thumbstick.release_virtual_thumbstick()
          _left_virtual_thumbstick.queue_free()
          _left_virtual_thumbstick = null
    else:
      if value > PRESSED_THRESHOLD:
        _left_hand_pinching = true
        if _is_menu_gesture_ready:
          if not _is_openxr_hand_tracking_aim_enabled():
            _toggle_menu()
        else:
          if menu_active:
            xr_tracker.set_input(PINCH_POINTER_ACTION, true)
          else:
            if movement_style == "teleportation":
              xr_tracker.set_input(THUMBSTICK_TELEPORT_ACTION, true)
            else:
              _left_virtual_thumbstick = XRVirtualThumbstickScene.instantiate()
              xr_origin.add_child(_left_virtual_thumbstick)
              _left_virtual_thumbstick.setup_virtual_thumbstick(left_controller, VIRTUAL_ROTATION_ACTION, Vector3(1.0, 0.0, 1.0))

func _on_xr_controller_3d_right_input_float_changed(name: String, value: float) -> void:
  if name == "pinch":
    if _right_hand_pinching:
      if value < RELEASED_THRESHOLD:
        _right_hand_pinching = false

        if _right_virtual_thumbstick:
          _right_virtual_thumbstick.release_virtual_thumbstick()
          _right_virtual_thumbstick.queue_free()
          _right_virtual_thumbstick = null
    else:
      if value > PRESSED_THRESHOLD:
        _right_hand_pinching = true

        _right_virtual_thumbstick = XRVirtualThumbstickScene.instantiate()
        xr_origin.add_child(_right_virtual_thumbstick)
        _right_virtual_thumbstick.setup_virtual_thumbstick(right_controller, VIRTUAL_ROTATION_ACTION, Vector3(1.0, 0.0, 0.0))

func _on_hand_tracking_aim_left_button_pressed(name: String) -> void:
  if name == "menu_gesture":
    _is_menu_gesture_ready = true
  elif name == "menu_pressed":
    _toggle_menu()

func _on_hand_tracking_aim_left_button_released(name: String) -> void:
  if name == "menu_gesture":
    _is_menu_gesture_ready = false

func _on_hand_tracking_left_tracking_changed(tracking: bool) -> void:
  left_hand_tracking.visible = tracking
  left_controller_hand.visible = not tracking
  left_controller.get_node("FunctionPointer").active_button_action = PINCH_POINTER_ACTION if tracking else TRIGGER_POINTER_ACTION
  %XRToolsMovementDirect.input_action = VIRTUAL_ROTATION_ACTION if tracking else REAL_ROTATION_ACTION

func _on_hand_tracking_right_tracking_changed(tracking: bool) -> void:
  right_hand_tracking.visible = tracking
  right_controller_hand.visible = not tracking
  %XRToolsMovementTurn.input_action = VIRTUAL_ROTATION_ACTION if tracking else REAL_ROTATION_ACTION
