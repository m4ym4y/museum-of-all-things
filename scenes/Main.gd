extends Node

@export var XrRoot : PackedScene = preload("res://scenes/XRRoot.tscn")
@export var Player : PackedScene = preload("res://scenes/Player.tscn")
var _player

@export var smooth_movement = false
@export var smooth_movement_dampening = 0.001
@export var player_speed = 6

@export var starting_point = Vector3(-7, 0, -2)
@export var starting_rotation = 3 * PI / 2

@onready var game_started = false
@onready var menu_nav_queue = []

func _init() -> void:
  _player = XrRoot.instantiate() if Util.is_xr() else Player.instantiate()
  add_child(_player)

  if Util.is_xr():
    _player = _player.get_node("XROrigin3D")

func _ready():
  if OS.has_feature("movie"):
    $FpsLabel.visible = false

  if Util.is_xr():
    _player.get_node("XRToolsPlayerBody").rotate_player(-starting_rotation)
    _start_game()
  else:
    _player.get_node("Pivot/Camera3D").make_current()
    _player.rotation.y = starting_rotation
    _player.max_speed = player_speed
    _player.smooth_movement = smooth_movement
    _player.dampening = smooth_movement_dampening
  _player.position = starting_point

  _pause_game()

func _start_game():
  if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

  if not Util.is_xr():
    _player.start()

  $CanvasLayer.visible = false

  if not game_started:
    game_started = true
    $Museum.init(_player)

func _pause_game():
  $CanvasLayer.visible = true

  if not Util.is_xr():
    _player.pause()

  if game_started:
    _open_settings_menu()
  else:
    _open_main_menu()

func _open_settings_menu():
  $CanvasLayer/Settings.visible = true
  $CanvasLayer/MainMenu.visible = false

func _open_main_menu():
  $CanvasLayer/MainMenu.visible = true
  $CanvasLayer/Settings.visible = false

func _on_main_menu_start_pressed():
  _start_game()

func _on_main_menu_settings():
  menu_nav_queue.append(_open_main_menu)
  _open_settings_menu()

func _on_settings_back():
  var prev = menu_nav_queue.pop_back()
  if prev:
    prev.call()
  else:
    _start_game()

func _input(event):
  if not game_started:
    return

  if event.is_action_pressed("pause"):
    _pause_game()

  if event is InputEventKey and Input.is_key_pressed(KEY_P):
    var vp = get_viewport()
    vp.debug_draw = (vp.debug_draw + 1 ) % 4
  if event.is_action_pressed("ui_cancel"):
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  if event.is_action_pressed("click"):
    if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
      Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  $FpsLabel.text = str(Engine.get_frames_per_second())
