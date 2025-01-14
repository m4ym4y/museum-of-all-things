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
    GraphicsManager.init()
    _player.get_node("Pivot/Camera3D").make_current()
    _player.rotation.y = starting_rotation
    _player.max_speed = player_speed
    _player.smooth_movement = smooth_movement
    _player.dampening = smooth_movement_dampening
  _player.position = starting_point

  GlobalMenuEvents.return_to_lobby.connect(_on_pause_menu_return_to_lobby)
  if not _xr:
    _pause_game()

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
    _open_pause_menu()
  else:
    _open_main_menu()

func _close_menus():
  $CanvasLayer.visible = false
  $CanvasLayer/Settings.visible = false
  $CanvasLayer/MainMenu.visible = false
  $CanvasLayer/PauseMenu.visible = false

func _open_settings_menu():
  $CanvasLayer.visible = true
  $CanvasLayer/Settings.visible = true
  $CanvasLayer/MainMenu.visible = false
  $CanvasLayer/PauseMenu.visible = false

func _open_main_menu():
  $CanvasLayer.visible = true
  $CanvasLayer/MainMenu.visible = true
  $CanvasLayer/Settings.visible = false
  $CanvasLayer/PauseMenu.visible = false

func _open_pause_menu():
  $CanvasLayer.visible = true
  $CanvasLayer/MainMenu.visible = false
  $CanvasLayer/Settings.visible = false
  $CanvasLayer/PauseMenu.visible = true

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
  if not game_started:
    return

  if (
    Input.is_action_just_pressed("ui_cancel") or
    Input.is_action_just_pressed("pause")
  ):
    GlobalMenuEvents.emit_ui_cancel_pressed()

  if event.is_action_pressed("pause") and not _xr:
    _pause_game()

  if event is InputEventKey and Input.is_key_pressed(KEY_P):
    var vp = get_viewport()
    vp.debug_draw = (vp.debug_draw + 1 ) % 4
  if event.is_action_pressed("free_pointer") and not _xr:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  if event.is_action_pressed("click") and not _xr:
    if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
      Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  $FpsLabel.text = str(Engine.get_frames_per_second())
