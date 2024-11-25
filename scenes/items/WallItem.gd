extends Node3D

@onready var ImageItem = preload("res://scenes/items/ImageItem.tscn")
@onready var TextItem = preload("res://scenes/items/TextItem.tscn")
@onready var _item_node = $Item
@onready var _item
@onready var _ceiling = $Ceiling
@onready var _light = get_node("Item/SpotLight3D")
@onready var _frame = get_node("Item/Frame")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _start_animate():
	var tween = create_tween()
	var light_tween = create_tween()
	var ceiling_tween = create_tween()

	tween.tween_property(
		_item_node,
		"position",
		_item_node.position + Vector3(0, 4, 0),
		0.5 # duration
	)

	ceiling_tween.tween_property(
		_ceiling,
		"position",
		_ceiling.position - Vector3(0, 2, 0),
		0.5 # duration
	)

	light_tween.tween_property(
		_light,
		"light_energy",
		3.0,
		1.0
	)

	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)

	light_tween.set_trans(Tween.TRANS_LINEAR)
	light_tween.set_ease(Tween.EASE_IN_OUT)

	ceiling_tween.set_trans(Tween.TRANS_LINEAR)
	ceiling_tween.set_ease(Tween.EASE_IN_OUT)

func _on_image_item_loaded():
	var size = _item.get_image_size()
	if size.x > size.y:
		_frame.scale.y = size.y / float(size.x)
	else:
		_frame.scale.x = size.x / float(size.y)
	_frame.position = _item.position
	_frame.position.z = 0
	_start_animate()

func init(item_data):
	if item_data.type == "image":
		_item = ImageItem.instantiate()
		_item.init(item_data.src, 2, 2, item_data.text)
		_item.loaded.connect(_on_image_item_loaded)
	elif item_data.type == "text":
		_frame.visible = false
		_item = TextItem.instantiate()
		_item.init(item_data.text)
		_start_animate()
	else:
		return
	_item.position = Vector3(0, 0, 0.07)
	_item_node.add_child(_item)
