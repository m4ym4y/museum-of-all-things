extends Node

@export var XrRoot : PackedScene = preload("res://scenes/XRRoot.tscn")
@export var Player : PackedScene = preload("res://scenes/Player.tscn")
var _player

@export var smooth_movement = false
@export var smooth_movement_dampening = 0.001
@export var player_speed = 6

@export var starting_point = Vector3(0, 4, 0)
@export var starting_rotation = 0 #3 * PI / 2

@onready var game_started = false
@onready var menu_nav_queue = []
@onready var _xr = Util.is_xr()

func _init() -> void:
  _player = XrRoot.instantiate() if Util.is_xr() else Player.instantiate()
  add_child(_player)

  if Util.is_xr():
    _player = _player.get_node("XROrigin3D")

func _ready():
  if OS.has_feature("movie"):
    $FpsLabel.visible = false

  if _xr:
    _player.get_node("XRToolsPlayerBody").rotate_player(-starting_rotation)
    _start_game()
  else:
    GraphicsManager.change_post_processing.connect(_change_post_processing)
    GraphicsManager.init()
    _player.get_node("Pivot/Camera3D").make_current()
    _player.rotation.y = starting_rotation
    _player.max_speed = player_speed
    _player.smooth_movement = smooth_movement
    _player.dampening = smooth_movement_dampening
  _player.position = starting_point

  GlobalMenuEvents.return_to_lobby.connect(_on_pause_menu_return_to_lobby)
  GlobalMenuEvents.open_terminal_menu.connect(_use_terminal)

  call_deferred("_play_sting")

  $DirectionalLight3D.visible = Util.is_compatibility_renderer()

  if not _xr:
    _pause_game()

func _play_sting():
  $GameLaunchSting.play()

func _change_post_processing(post_processing: String):
  if post_processing == "crt":
    $CRTPostProcessing.visible = true
  else:
    $CRTPostProcessing.visible = false

func _start_game():
  if not _xr:
    if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
      Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    _player.start()

  _close_menus()

  if not game_started:
    game_started = true
    $Museum.init(_player)

func _pause_game():
  _player.pause()

  if game_started:
    if $CanvasLayer.visible:
      return
    _open_pause_menu()
  else:
    _open_main_menu()

func _use_terminal():
  _player.pause()
  Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  _open_terminal_menu()

func _close_menus():
  $CanvasLayer.visible = false
  $CanvasLayer/Settings.visible = false
  $CanvasLayer/MainMenu.visible = false
  $CanvasLayer/PauseMenu.visible = false
  $CanvasLayer/PopupTerminalMenu.visible = false

func _open_settings_menu():
  _close_menus()
  $CanvasLayer.visible = true
  $CanvasLayer/Settings.visible = true

func _open_main_menu():
  _close_menus()
  $CanvasLayer.visible = true
  $CanvasLayer/MainMenu.visible = true

func _open_pause_menu():
  _close_menus()
  $CanvasLayer.visible = true
  $CanvasLayer/PauseMenu.visible = true

func _open_terminal_menu():
  _close_menus()
  $CanvasLayer.visible = true
  $CanvasLayer/PopupTerminalMenu.visible = true

func _on_main_menu_start_pressed():
  _start_game()

func _on_main_menu_settings():
  menu_nav_queue.append(_open_main_menu)
  _open_settings_menu()

func _on_pause_menu_settings():
  menu_nav_queue.append(_open_pause_menu)
  _open_settings_menu()

func _on_pause_menu_return_to_lobby():
  # TODO: set absolute rotation in XR
  if not Util.is_xr():
    _player.rotation.y = starting_rotation

  _player.position = starting_point
  $Museum.reset_to_lobby()

  _start_game()

func _on_settings_back():
  var prev = menu_nav_queue.pop_back()
  if prev:
    prev.call()
  else:
    _start_game()

func _input(event):

  if Input.is_action_pressed("toggle_fullscreen"):
    $CanvasLayer/Settings/ScrollContainer/MarginContainer/VBoxContainer/MarginContainer/GraphicsSettings/DisplayOptions/Fullscreen.button_pressed = not GraphicsManager.fullscreen


  if not game_started:
    return

  if Input.is_action_just_pressed("ui_accept"):
    GlobalMenuEvents.emit_ui_accept_pressed()

  if Input.is_action_just_pressed("ui_cancel") and $CanvasLayer.visible:
    GlobalMenuEvents.emit_ui_cancel_pressed()

  if Input.is_action_just_pressed("show_fps"):
    $FpsLabel.visible = not $FpsLabel.visible

  if event.is_action_pressed("pause") and not _xr:
    _pause_game()

  
  if event.is_action_pressed("free_pointer") and not _xr:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  if event.is_action_pressed("click") and not _xr and not $CanvasLayer.visible:
    if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
      Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  $FpsLabel.text = str(Engine.get_frames_per_second())
