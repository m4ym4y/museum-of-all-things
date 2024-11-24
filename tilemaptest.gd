@tool
extends Node3D

@onready var Portal = preload("res://Portal.tscn")
@onready var LoaderTrigger = preload("res://loader_trigger.tscn")
@onready var TiledExhibitGenerator = preload("res://tiled_exhibit_generator.tscn")

# item types
@onready var WallItem = preload("res://room_items/wall_item.tscn")
@onready var IMAGE_REGEX = RegEx.new()

@onready var _fetcher = $ExhibitFetcher
@onready var _next_height = 0
var _grid

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  IMAGE_REGEX.compile("\\.(png|jpg|jpeg)$")
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

func set_up_exhibit(exhibit, room_count=default_room_count, title="Lobby", prev_title="Lobby"):
  var generated_results = exhibit.generate(
      _grid,
      Vector3(0, _next_height, 0),
      min_room_dimension,
      max_room_dimension,
      room_count,
      title,
      prev_title,
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
    loader_trigger.body_entered.connect(_on_loader_body_entered.bind(exit_portal, entry_portal, loader_trigger, exit[2], title))
    add_child(exit_portal)
    add_child(loader_trigger)
    add_child

  return entry_portal

func _on_loader_body_entered(body, exit_portal, entry_portal, loader_trigger, label, title):
  if body.is_in_group("Player") and loader_trigger.loaded == false:
    loader_trigger.loaded = true
    var next_article = coalesce(label.text, "Fungus")
    # var next_article = coalesce(label.text, "Lahmiales")
    # var next_article = coalesce(label.text, "Tribe (biology)")
    # var next_article = coalesce(label.text, "Diploid")
    # var next_article = coalesce(label.text, "USA")
    _fetcher.fetch([next_article], {
      "title": next_article,
      "prev_title": title,
      "exit_portal": exit_portal,
      "entry_portal": entry_portal,
      "loader_trigger": loader_trigger,
      "next_article": next_article,
    })

func _result_to_exhibit_data(result):
  var items = []
  var doors = []

  if result:
    if result.has("extract"):
      items.append({
        "type": "text",
        "text": result.extract
      })

    if result.has("links"):
      doors = result.links.duplicate()
      doors.shuffle()

    if result.has("images"):
      for image in result.images:
        if IMAGE_REGEX.search(image.src):
          items.append({
            "type": "image",
            "src": image.src,
            "text": image.text,
          })

  return {
    "doors": doors,
    "items": items,
  }

func _init_item(item, data):
  add_child(item)
  item.init(data)

func _on_fetch_complete(_titles, context):
  # we don't need to do anything to handle a prefetch
  if context.has("prefetch"):
    return

  var result = _fetcher.get_result(context.title)
  if not result:
    print("NO RESULT", _titles)

  var data = _result_to_exhibit_data(result)
  var doors = data.doors
  var items = data.items

  _next_height += 20
  var new_exhibit = TiledExhibitGenerator.instantiate()
  add_child(new_exhibit)
  var new_exhibit_portal = set_up_exhibit(
    new_exhibit,
    max(len(items) / 6, 1),
    context.title,
    context.prev_title
  )

  context.exit_portal.exit_portal = new_exhibit_portal
  new_exhibit_portal.exit_portal = context.exit_portal

  var exits = new_exhibit.exits
  var slots = new_exhibit.item_slots
  var linked_exhibits = []

  # fill in doors out of the exhibit
  for exit in exits:
    var linked_exhibit = coalesce(doors.pop_front(), "")
    exit[2].text = linked_exhibit
    linked_exhibits.append(linked_exhibit)

  var delay = 0.0
  for slot in slots:
    var item_data = items.pop_front()
    if item_data == null:
      break

    var item = WallItem.instantiate()
    item.position = gridToWorld(slot[0]) - slot[1] * 0.01
    item.rotation.y = vecToRot(slot[1])

    # we use a delay to stop there from being a frame drop when a bunch of items are added at once
    get_tree().create_timer(delay).timeout.connect(_init_item.bind(item, item_data))
    delay += 0.1

  # launch batch request to linked exhibit
  # print("prefetching articles ", linked_exhibits)
  # _fetcher.fetch(linked_exhibits, { "prefetch": true })

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
@export var default_room_count: int = 4
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
