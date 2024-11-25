@tool
extends Node3D

# @onready var Portal = preload("res://scenes/Portal.tscn")
@onready var LoaderTrigger = preload("res://scenes/LoaderTrigger.tscn")
@onready var TiledExhibitGenerator = preload("res://scenes/TiledExhibitGenerator.tscn")
@onready var DEFAULT_DOORS = [
  "Fungus",
  "Soup",
  "Albert Einstein",
  "Dinosaur",
  "USA",
]

# item types
@onready var WallItem = preload("res://scenes/items/WallItem.tscn")
@onready var IMAGE_REGEX = RegEx.new()

@onready var _fetcher = $ExhibitFetcher
@onready var _loaded_exhibit = $TiledExhibitGenerator
@onready var _loaded_exhibit_title = "Lobby"
@onready var _next_height = 0
var _grid

func _init():
  RenderingServer.set_debug_generate_wireframes(true)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  IMAGE_REGEX.compile("\\.(png|jpg|jpeg)$")
  if Engine.is_editor_hint():
    return
  else:
    _grid = $GridMap
    _grid.clear()
    _fetcher.fetch_complete.connect(_on_fetch_complete)
    set_up_exhibit($TiledExhibitGenerator)

    # set up default exhibits in lobby
    var exits = $TiledExhibitGenerator.exits
    for exit in exits:
      var linked_exhibit = Util.coalesce(DEFAULT_DOORS.pop_front(), "Fungus")
      exit.to_label.text = linked_exhibit

func set_up_exhibit(exhibit, pos=null, dir=null, room_count=default_room_count, title="Lobby", prev_title="Lobby", start_hall_override=null):
  if start_hall_override:
    print("calling generate %s %s %s %s %s %s %s" % [pos, dir, room_count, title, prev_title, start_hall_override.to_pos, start_hall_override.to_dir])
  else:
    print("calling generate %s %s %s %s %s" % [pos, dir, room_count, title, prev_title])

  var generated_results = exhibit.generate(
      _grid,
      Util.coalesce(pos, Vector3.ZERO),
      Util.coalesce(dir, Vector3(1, 0, 0)),
      min_room_dimension,
      max_room_dimension,
      room_count,
      title,
      prev_title,
      start_hall_override
  )

  var entry = generated_results.entry
  var exits = generated_results.exits

  # bind to every exit preloader
  for exit in exits:
    exit.loader.body_entered.connect(_on_preloader_body_entered.bind(exit))
    exit.detector.direction_changed.connect(_on_change_loaded_room.bind(exit))

func _on_preloader_body_entered(body, exit):
  if body.is_in_group("Player") and exit.loader.loaded == false:
    exit.loader.loaded = true
    var next_article = Util.coalesce(exit.to_label.text, "Fungus")
    # var next_article = coalesce(label.text, "Lahmiales")
    # var next_article = coalesce(label.text, "Tribe (biology)")
    # var next_article = coalesce(label.text, "Diploid")
    # var next_article = coalesce(label.text, "USA")

    _fetcher.fetch([next_article], {
      "title": next_article,
      "exit": exit,
      # TODO: we may actually need to handle this
      "prefetch": true
    })

func _on_change_loaded_room(direction, exit):
  var title
  var prev_title
  var start_pos
  var start_dir
  var start_hall_override
  if direction == "entry":
    title = exit.from_label.text
    prev_title = exit.to_label.text
    start_pos = exit.from_room_root
    start_dir = exit.from_room_root_dir
  else:
    title = exit.to_label.text
    prev_title = exit.from_label.text
    start_pos = exit.from_pos
    start_dir = exit.from_dir
    start_hall_override = exit

  if title == _loaded_exhibit_title:
    return

  var result = _fetcher.get_result(Util.coalesce(title, "Fungus"))
  if not result:
    print("NO RESULT", title)
    return

  # print("opening exit door")
  exit.tree_exited.connect(_on_tree_exit_print.bind(exit.to_label.text))
  exit.init_called.connect(_on_init_call_print.bind(exit.to_label.text))
  # exit.exit_door.open()
  # exit.entry_door.open()

  _loaded_exhibit_title = title
  var new_exhibit = TiledExhibitGenerator.instantiate()
  add_child(new_exhibit)

  # if direction == "exit":
  exit.reparent(new_exhibit)
  await get_tree().process_frame
  exit.exit_door.set_open(direction == "exit")
  exit.entry_door.set_open(direction == "entry")

  _loaded_exhibit.queue_free()
  await _loaded_exhibit.tree_exited
  await get_tree().process_frame

  _loaded_exhibit = new_exhibit

  var data = _result_to_exhibit_data(title, result)
  var doors = data.doors
  var items = data.items

  set_up_exhibit(
    new_exhibit,
    start_pos,
    start_dir,
    max(len(items) / 6, 1),
    title,
    prev_title,
    start_hall_override
  )

  # fill in doors out of the exhibit
  for new_exit in new_exhibit.exits:
    var linked_exhibit = Util.coalesce(doors.pop_front(), "")
    new_exit.to_label.text = linked_exhibit

  var slots = new_exhibit.item_slots
  var delay = 0.0
  for slot in slots:
    var item_data = items.pop_front()
    if item_data == null:
      break

    var item = WallItem.instantiate()
    new_exhibit.add_child(item)
    item.position = Util.gridToWorld(slot[0]) - slot[1] * 0.01
    item.rotation.y = Util.vecToRot(slot[1])

    # _init_item(item, item_data)
    # we use a delay to stop there from being a frame drop when a bunch of items are added at once
    get_tree().create_timer(delay).timeout.connect(_init_item.bind(item, item_data))
    delay += 0.1

func _seeded_shuffle(seed, arr):
  var rng = RandomNumberGenerator.new()
  var n = len(arr)
  rng.seed = hash(seed)

  for i in range(n - 1, 0, -1):
    var j = rng.randi() % (i + 1) # Get a random index in range [0, i]
    # Swap elements at indices i and j
    var temp = arr[i]
    arr[i] = arr[j]
    arr[j] = temp

func _result_to_exhibit_data(title, result):
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
      _seeded_shuffle(title, doors)

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
  if is_instance_valid(item):
    item.init(data)

func _on_fetch_complete(_titles, context):
  # TODO: we may need to open a door here
  pass

func _input(event):
  if event is InputEventKey and Input.is_key_pressed(KEY_P):
    var vp = get_viewport()
    vp.debug_draw = (vp.debug_draw + 1 ) % 4
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
    return

func _clear_group(group):
  for scene in get_tree().get_nodes_in_group(group):
    scene.queue_free()

func _on_tree_exit_print(arg):
  print("node exiting treeeee", arg)

func _on_init_call_print(arg):
  print("node init call", arg)
