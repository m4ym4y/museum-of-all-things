extends Node3D

@onready var _door = $Door
@onready var _open = false
var _open_pos = Vector3(0, 6.5, 0)
var _closed_pos = Vector3(0, 2, 0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func open():
	set_open(true)

func close():
	set_open(false)

func set_open(open = true, instant = false):
	if is_visible() and not instant:
		var tween = get_tree().create_tween()
		tween.tween_property(
			_door,
			"position",
			_open_pos if open else _closed_pos,
			1.0
		)
	else:
		_door.position = _open_pos if open else _closed_pos

@onready var label_pivot = $Door/LabelPivot
@onready var top_label = $Door/LabelPivot/Label1
@onready var bottom_label = $Door/LabelPivot/Label2
var _label_tween = null

func set_message(msg, instant = false):
	if _label_tween:
		_label_tween.kill()

	bottom_label.text = msg

	if is_visible() and not instant:
		_label_tween = get_tree().create_tween()
		_label_tween.tween_property(
			label_pivot,
			"rotation:z",
			label_pivot.rotation.z + PI,
			2.5
		)
	else:
		_label_tween = null
		label_pivot.rotation.z += PI

	var tmp = top_label
	top_label = bottom_label
	bottom_label = tmp

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
