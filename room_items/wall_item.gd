extends Node3D

@onready var ImageItem = preload("res://room_items/ImageItem.tscn")
@onready var TextItem = preload("res://room_items/TextItem.tscn")
@onready var _item_node = $Item
@onready var _ceiling = $Ceiling
@onready var _light = get_node("Item/SpotLight3D")

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
	_start_animate()

func init(item_data):
	var item
	if item_data.type == "image":
		item = ImageItem.instantiate()
		item.init(item_data.src, 2, 2, item_data.text)
		item.loaded.connect(_on_image_item_loaded)
	elif item_data.type == "text":
		item = TextItem.instantiate()
		item.init(item_data.text)
		_start_animate()
	else:
		return
	item.position = Vector3(0, 0, 0.11)
	_item_node.add_child(item)
