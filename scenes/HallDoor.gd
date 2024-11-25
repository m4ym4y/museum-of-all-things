extends Node3D

@onready var _door = $Door
@onready var _open = false
var _open_pos = Vector3(0, 5, 0)
var _closed_pos = Vector3(0, 1.5, 0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func open():
	set_open(true)

func close():
	set_open(false)

func set_open(open = true):
	_open = open
	_door.position = _open_pos if open else _closed_pos
	"""var tween = get_tree().create_tween()
	tween.tween_property(
		_door,
		"position",
		_open_pos if open else _closed_pos,
		1.0
	)"""

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
