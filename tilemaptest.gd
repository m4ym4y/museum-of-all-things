@tool
extends Node3D

@onready var Portal = preload("res://Portal.tscn")
@onready var LoaderTrigger = preload("res://loader_trigger.tscn")
@onready var TiledExhibitGenerator = preload("res://tiled_exhibit_generator.tscn")

# item types
@onready var ImageItem = preload("res://room_items/ImageItem.tscn")
@onready var TextItem = preload("res://room_items/TextItem.tscn")

@onready var _fetcher = $ExhibitFetcher
@onready var _next_height = 0
var _grid

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  if Engine.is_editor_hint():
    _regenerate_map()
  else:
    _grid = $GridMap
    _grid.clear()
    _fetcher.fetch_complete.connect(_on_fetch_complete)
    set_up_exhibit($TiledExhibitGenerator)

func vecToRot(vec):
  if vec.z < -0.1:
    return 0.0
  elif vec.z > 0.1:
    return PI
  elif vec.x > 0.1:
    return 3 * PI / 2
  elif vec.x < -0.1:
    return PI / 2
  return 0.0

func gridToWorld(vec):
  return 4 * vec

func coalesce(a, b):
  return a if a else b

func set_up_exhibit(exhibit):
  var generated_results = exhibit.generate(
      _grid,
      Vector3(0, _next_height, 0),
      min_room_dimension,
      max_room_dimension,
      room_count
  )

  var entry = generated_results[0]
  var exits = generated_results[1]

  var entry_portal = Portal.instantiate()
  entry_portal.rotation.y = vecToRot(entry[1]) + PI
  entry_portal.position = gridToWorld(entry[0]) + Vector3(0, 1.5, 0)
  entry_portal.exit_portal = entry_portal
  add_child(entry_portal)

  # add a marker at every exit
  for exit in exits:
    var exit_portal = Portal.instantiate()
    exit_portal.rotation.y = vecToRot(exit[1])
    exit_portal.position = gridToWorld(exit[0]) + Vector3(0, 1.5, 0)
    exit_portal.exit_portal = entry_portal
    var loader_trigger = LoaderTrigger.instantiate()
    loader_trigger.monitoring = true
    loader_trigger.position = gridToWorld(exit[0] - exit[1] - exit[1].rotated(Vector3(0, 1, 0), PI / 2))
    loader_trigger.body_entered.connect(_on_loader_body_entered.bind(exit_portal, entry_portal, loader_trigger, exit[2]))
    add_child(exit_portal)
    add_child(loader_trigger)
    add_child

  return entry_portal

func _on_loader_body_entered(body, exit_portal, entry_portal, loader_trigger, label):
  if body.is_in_group("Player") and loader_trigger.loaded == false:
    loader_trigger.loaded = true
    _next_height += 10
    var new_exhibit = TiledExhibitGenerator.instantiate()
    var new_exhibit_portal = set_up_exhibit(new_exhibit)
    exit_portal.exit_portal = new_exhibit_portal
    new_exhibit_portal.exit_portal = exit_portal
    add_child(new_exhibit)
    var next_article = coalesce(label.text, "Fungus")
    _fetcher.fetch(next_article, {
      "exit_portal": exit_portal,
      "entry_portal": entry_portal,
      "loader_trigger": loader_trigger,
      "next_article": next_article,
      "new_exhibit": new_exhibit
    })

func _on_fetch_complete(data, context):
  var doors = data.doors.duplicate()
  var items = data.items.duplicate()
  var exits = context.new_exhibit.exits
  var slots = context.new_exhibit.item_slots

  # fill in doors out of the exhibit
  for exit in exits:
    exit[2].text = coalesce(data.doors.pop_front(), "")

  for slot in slots:
    print(slot[0])
    var data_item = items.pop_front()
    if data_item == null:
      break

    var item
    if data_item.type == "image":
      item = ImageItem.instantiate()
      item.init(data_item.src, 2, 2, data_item.text)
    elif data_item.type == "text":
      item = TextItem.instantiate()
      item.init(data_item.text)
    else:
      continue

    item.position = gridToWorld(slot[0]) + Vector3(0, 2, 0) - slot[1] * 0.01
    item.rotation.y = vecToRot(slot[1])

    add_child(item)

func _input(event):
  if event.is_action_pressed("ui_cancel"):
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  if event.is_action_pressed("click"):
    if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
      Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
  pass

@export var min_room_dimension: int = 2
@export var max_room_dimension: int = 5
@export var room_count: int = 4
@export var iterations: int = 1

@export var regenerate_starting_exhibit: bool = false:
  set(new_value):
    _regenerate_map()

func _clear_group(group):
  for scene in get_tree().get_nodes_in_group(group):
    scene.queue_free()

func _regenerate_map():
  _grid = $GridMap

  _grid.clear()
  _clear_group("Portal")
  _clear_group("Loader")

  set_up_exhibit($TiledExhibitGenerator)

  for _n in range(iterations - 1):
    _next_height += 10
    var next_exhibit = TiledExhibitGenerator.instantiate()
    set_up_exhibit(next_exhibit)
    add_child(next_exhibit)
