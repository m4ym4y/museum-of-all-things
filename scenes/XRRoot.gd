extends Node3D

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
