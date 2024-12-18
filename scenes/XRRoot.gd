extends Node3D

@onready var left_controller = $XROrigin3D/XRController3D_left
@onready var right_controller = $XROrigin3D/XRController3D_right

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
    GlobalMenuEvents.hide_menu.connect(hide_menu)

var menu_active = false
var by_button_pressed = false

func hide_menu():
  menu_active = false
  left_controller.get_node("FunctionPointer").enabled = false
  left_controller.get_node("FunctionTeleport").enabled = true
  right_controller.get_node("XrMenu").visible = false

func show_menu():
  menu_active = true
  left_controller.get_node("FunctionPointer").enabled = true
  left_controller.get_node("FunctionTeleport").enabled = false
  right_controller.get_node("XrMenu").visible = true

func _physics_process(delta: float) -> void:
  if right_controller and right_controller.is_button_pressed("by_button") and not by_button_pressed:
    by_button_pressed = true
    if not menu_active:
      show_menu()
    else:
      hide_menu()
  elif right_controller and not right_controller.is_button_pressed("by_button") and by_button_pressed:
    by_button_pressed = false
