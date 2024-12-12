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

func _start_game():
  if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

  if not Util.is_xr():
    _player.init()

  game_started = true
  $CanvasLayer.queue_free()
  $Museum.init(_player)

func _input(event):
  if not game_started:
    return

  if event is InputEventKey and Input.is_key_pressed(KEY_P):
    var vp = get_viewport()
    vp.debug_draw = (vp.debug_draw + 1 ) % 4
  if event.is_action_pressed("ui_cancel"):
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  if event.is_action_pressed("click"):
    if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
      Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_button_pressed():
  _start_game()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  $FpsLabel.text = str(Engine.get_frames_per_second())
