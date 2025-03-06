extends Node3D

@onready var ImageItem = preload("res://scenes/items/ImageItem.tscn")
@onready var TextItem = preload("res://scenes/items/TextItem.tscn")
@onready var RichTextItem = preload("res://scenes/items/RichTextItem.tscn")

@onready var MarbleMaterial = preload("res://assets/textures/marble21.tres")
@onready var WhiteMaterial = preload("res://assets/textures/flat_white.tres")
@onready var WoodMaterial = preload("res://assets/textures/wood_2.tres")
@onready var BlackMaterial = preload("res://assets/textures/black.tres")

@onready var _item_node = $Item
@onready var _item
@onready var _ceiling = $Ceiling
@onready var _light = get_node("Item/SpotLight3D")
@onready var _frame = get_node("Item/Frame")
@onready var _animate_item_target = _item_node.position + Vector3(0, 4, 0)
@onready var _animate_ceiling_target = _ceiling.position - Vector3(0, 2, 0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass

func _start_animate():
  var player = get_tree().get_first_node_in_group("Player")
  var tween_time = 0.5

  if not player or position.distance_to(player.global_position) > $Item/Plaque.visibility_range_end:
    tween_time = 0
  else:
    $SlideSound.play()

  var tween = create_tween()
  var light_tween = create_tween()
  var ceiling_tween = create_tween()

  tween.tween_property(
    _item_node,
    "position",
    _animate_item_target,
    tween_time
  )

  ceiling_tween.tween_property(
    _ceiling,
    "position",
    _animate_ceiling_target,
    tween_time
  )

  if Util.is_compatibility_renderer():
    # On the compatibility renderer, this will get faded in by the GraphicsManager.
    light_tween.kill()
    _light.visible = false
  else:
    light_tween.tween_property(
      _light,
      "light_energy",
      3.0,
      tween_time
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
  if item_data.has("material"):
    if item_data.material == "marble":
      $Item/Plaque.material_override = MarbleMaterial
    if item_data.material == "white":
      $Item/Plaque.material_override = WhiteMaterial
    elif item_data.material == "none":
      $Item/Plaque.visible = false
      _animate_item_target.z -= 0.05

  if item_data.type == "image":
    _item = ImageItem.instantiate()
    _item.loaded.connect(_on_image_item_loaded)
    _item.init(item_data.title, item_data.text, item_data.plate)
  elif item_data.type == "text":
    _frame.visible = false
    _item = TextItem.instantiate()
    _item.init(item_data.text)
    _start_animate()
  elif item_data.type == "rich_text":
    _frame.visible = false
    _item = RichTextItem.instantiate()
    _item.init(item_data.text)
    _start_animate()
  else:
    return
  _item.position = Vector3(0, 0, 0.07)
  _item_node.add_child(_item)
