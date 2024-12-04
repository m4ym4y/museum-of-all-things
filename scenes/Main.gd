extends Node

@export var XrRoot : PackedScene = preload("res://scenes/XRRoot.tscn")
var _player

func _init() -> void:
  _player = XrRoot.instantiate() if Util.is_xr() else null

  if Util.is_xr():
    add_child(_player)
    _player = _player.get_node("XROrigin3D")

func _ready():
  if not Util.is_xr():
    _player = $Player

  $Museum.init(_player)

  if Util.is_xr():
    $Player.queue_free()
    _player.get_node("XRToolsPlayerBody").rotate_player(-3 * PI / 2)
  else:
    _player.rotation.y = 3 * PI / 2

  _player.position = Vector3(-6, 0, -2)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass
