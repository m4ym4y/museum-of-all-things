extends Node

@export var Player : PackedScene = preload("res://scenes/Player.tscn")
@export var XrRoot : PackedScene = preload("res://scenes/XRRoot.tscn")
var _player

func _init() -> void:
	_player = XrRoot.instantiate() if Util.is_xr() else Player.instantiate()
	_player.position = Vector3(4, 0, 6)
	_player.rotation.y = PI
	add_child(_player)
	
	if Util.is_xr():
		_player = _player.get_node("XROrigin3D")

func _ready():
	$Museum.init(_player)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
