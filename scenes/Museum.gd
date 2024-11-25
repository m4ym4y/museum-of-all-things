@tool
extends Node3D

@onready var Portal = preload("res://scenes/Portal.tscn")
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
@onready var _exhibit_hist = []
@onready var _exhibits = {}
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
      var linked_exhibit = Util.coalesce(DEFAULT_DOORS.pop_front(), "")
      exit.to_label.text = linked_exhibit

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

  var entry = generated_results.entry
  var exits = generated_results.exits

  var entry_portal = Portal.instantiate()
  entry_portal.rotation.y = Util.vecToRot(entry.to_dir) + PI
  entry_portal.position = Util.gridToWorld(entry.to_pos) + Vector3(0, 1.5, 0)
  entry_portal.exit_portal = entry_portal
  exhibit.add_child(entry_portal)

  # add a marker at every exit
  for exit in exits:
    var exit_portal = Portal.instantiate()
    exit_portal.rotation.y = Util.vecToRot(exit.to_dir)
    exit_portal.position = Util.gridToWorld(exit.to_pos) + Vector3(0, 1.5, 0)
    exit_portal.exit_portal = entry_portal
    exit.loader.body_entered.connect(_on_loader_body_entered.bind(exit_portal, entry_portal, exit))
    exhibit.add_child(exit_portal)

  return entry_portal

func _on_loader_body_entered(body, exit_portal, entry_portal, exit):
  if body.is_in_group("Player") and exit.loader.loaded == false:
    exit.loader.loaded = true
    var next_article = Util.coalesce(exit.to_label.text, "Fungus")
    # var next_article = coalesce(label.text, "Lahmiales")
    # var next_article = coalesce(label.text, "Tribe (biology)")
    # var next_article = coalesce(label.text, "Diploid")
    # var next_article = coalesce(label.text, "USA")
    if _exhibits.has(next_article):
      var next_exhibit = _exhibits[next_article]
      if next_exhibit.has("entry_portal"):
        var portal = next_exhibit.entry_portal
        exit_portal.exit_portal = portal
        portal.exit_portal = exit_portal

    _fetcher.fetch([next_article], {
      "title": next_article,
      "exit_portal": exit_portal,
      "entry_portal": entry_portal,
      "exit": exit,
    })

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

func _init_item(exhibit, item, data):
  if is_instance_valid(exhibit) and is_instance_valid(item):
    exhibit.add_child(item)
    item.init(data)

func _on_fetch_complete(_titles, context):
  # we don't need to do anything to handle a prefetch
  if context.has("prefetch"):
    return

  var result = _fetcher.get_result(context.title)
  if not result:
    # TODO: show an out of order sign
    return

  var data = _result_to_exhibit_data(context.title, result)
  var doors = data.doors
  var items = data.items

  _next_height += 20
  var new_exhibit = TiledExhibitGenerator.instantiate()
  add_child(new_exhibit)
  var new_exhibit_portal = set_up_exhibit(
    new_exhibit,
    max(len(items) / 6, 1),
    context.title,
    context.exit.from_label.text
  )

  context.exit_portal.exit_portal = new_exhibit_portal
  new_exhibit_portal.exit_portal = context.exit_portal

  if not _exhibits.has(context.title):
    _exhibits[context.title] = { "entry_portal": new_exhibit_portal, "exhibit": new_exhibit }
    _exhibit_hist.append(context.title)
    # TODO: never delete the exhibit the user is in
    # TODO: remember the history of exhibits and where their entries should go, and where we exited them from
    # clearly this isn't ready yet
    """
    if len(_exhibit_hist) > max_exhibits_loaded:
      var key = _exhibit_hist.pop_front()
      if _exhibits.has(key):
        var old_exhibit = _exhibits[key]
        if old_exhibit.has('exhibit'):
          old_exhibit.exhibit.queue_free()
        _exhibits.erase(key)
    """

  context.exit.exit_door.open()

  var exits = new_exhibit.exits
  var slots = new_exhibit.item_slots
  var linked_exhibits = []

  # fill in doors out of the exhibit
  for exit in exits:
    var linked_exhibit = Util.coalesce(doors.pop_front(), "")
    exit.to_label.text = linked_exhibit
    linked_exhibits.append(linked_exhibit)

  var delay = 0.0
  for slot in slots:
    var item_data = items.pop_front()
    if item_data == null:
      break

    var item = WallItem.instantiate()
    item.position = Util.gridToWorld(slot[0]) - slot[1] * 0.01
    item.rotation.y = Util.vecToRot(slot[1])

    # we use a delay to stop there from being a frame drop when a bunch of items are added at once
    get_tree().create_timer(delay).timeout.connect(_init_item.bind(new_exhibit, item, item_data))
    delay += 0.1

  # launch batch request to linked exhibit
  # print("prefetching articles ", linked_exhibits)
  # _fetcher.fetch(linked_exhibits, { "prefetch": true })

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

@export var max_exhibits_loaded: int = 2
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
