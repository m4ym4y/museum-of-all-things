extends Node3D

@onready var NoImageNotice = preload("res://scenes/items/NoImageNotice.tscn")
@onready var TiledExhibitGenerator = preload("res://scenes/TiledExhibitGenerator.tscn")
@onready var QUEUE_DELAY = 0.05
@onready var DEFAULT_DOORS = [
  "Baroque painting",
  "List of Polish people",
  "Louvre",
  "Coffee",
  "Fungus",
  "Soup",
  "Albert Einstein",
  "Dinosaur",
  "USA",
  "Portland, Oregon",
  "Goncharov (meme)",
  "Persepolis",
  "Control Car",
  "Dragon",
  "Sister",
  "Arts in the Philippines",
  "Armenian Architecture",
  "Marine Life",
  "History of Germany",
  "Pablo Picasso",
  "Breast-shaped hill",
  "Freddy Mercury",
  "Chernobyl disaster",
  "Earth",
  "Petra",
  "Taipei 101",
  "Kobe Bryant",
  "Genghis Khan",
  "Titanic",
  "Graffiti",
  "Arabia quadrangle",
  "Architecture of Liverpool",
  "Minox",
]

@onready var INTRODUCTION = {
  "type": "rich_text",
  "material": "marble",
  "text": """
[center][color=black][b][font_size=75]MoAT[/font_size]

[font_size=50]Welcome to the Museum of All Things[/font_size][/b]
 
[font_size=25]
This museum contains all of wikipedia, and is free for you to explore. Each exhibit has been assembled using the images and text contained in its corresponding wikipedia page.
 
Additionally, every exhibit contains doors to many other interesting exhibits. These are chosen based on the pages that the exhibit's wikipedia page links to.
 
[b]Have fun exploring![/b]
"""
}

# item types
@onready var WallItem = preload("res://scenes/items/WallItem.tscn")
@onready var _xr = Util.is_xr()

@onready var _exhibit_hist = []
@onready var _exhibits = {}
@onready var _backlink_map = {}
@onready var _next_height = 20
@onready var _current_room_title = "$Lobby"
@export var items_per_room_estimate = 7
@export var min_rooms_per_exhibit = 2

@export var fog_depth = 10.0
@export var fog_depth_lobby = 20.0

var _grid
var _player

func _init():
  RenderingServer.set_debug_generate_wireframes(true)

func init(player):
  _player = player
  _set_up_lobby($Lobby)
  reset_to_lobby()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  $WorldEnvironment.environment.ssr_enabled = not _xr

  _grid = $Lobby/GridMap
  ExhibitFetcher.wikitext_complete.connect(_on_fetch_complete)
  ExhibitFetcher.wikidata_complete.connect(_on_wikidata_complete)
  ExhibitFetcher.commons_images_complete.connect(_on_commons_images_complete)

func _set_up_lobby(lobby):
  var exits = lobby.exits
  _exhibits["$Lobby"] = lobby
  lobby.get_node("Introduction").init(INTRODUCTION)

  if OS.is_debug_build():
    print("Setting up lobby with %s exits..." % len(exits))

  for exit in exits:
    var title = DEFAULT_DOORS.pop_front()
    if not title:
      break
    exit.to_title = title
    exit.loader.body_entered.connect(_on_loader_body_entered.bind(exit))

func get_current_room():
  return _current_room_title

func reset_to_lobby():
  _set_current_room_title("$Lobby")

func _set_current_room_title(title):
  _current_room_title = title
  ExhibitFetcher.switch_active_queue(title)
  GlobalMenuEvents.emit_set_current_room(title)
  _start_queue()

  var fog_color = Util.gen_fog(_current_room_title)
  var environment = $WorldEnvironment.environment

  if _current_room_title == "$Lobby":
    environment.fog_depth_begin = fog_depth_lobby
  else:
    environment.fog_depth_begin = fog_depth

  if environment.fog_light_color != fog_color:
    var tween = create_tween()
    tween.tween_property(
        environment,
        "fog_light_color",
        fog_color,
        1.0)

    tween.set_trans(Tween.TRANS_LINEAR)
    tween.set_ease(Tween.EASE_IN_OUT)

func _teleport_player(from_hall, to_hall, entry_to_exit=false):
  if is_instance_valid(from_hall) and is_instance_valid(to_hall):
    var pos = _player.global_position if not _xr else _player.get_node("XRCamera3D").global_position
    var distance = (from_hall.position - pos).length()
    if distance > max_teleport_distance:
      return
    var diff_from = _player.global_position - from_hall.position
    var rot_diff = Util.vecToRot(to_hall.to_dir) - Util.vecToRot(from_hall.to_dir)
    _player.global_position = to_hall.position + diff_from.rotated(Vector3(0, 1, 0), rot_diff)
    if not _xr:
      _player.global_rotation.y += rot_diff
    else:
      _player.get_node("XRToolsPlayerBody").rotate_player(-rot_diff)
    _set_current_room_title(from_hall.from_title if entry_to_exit else from_hall.to_title)
  elif is_instance_valid(from_hall):
    if entry_to_exit:
      _load_exhibit_from_entry(from_hall)
    else:
      _load_exhibit_from_exit(from_hall)
  elif is_instance_valid(to_hall):
    if entry_to_exit:
      _load_exhibit_from_exit(to_hall)
    else:
      _load_exhibit_from_entry(to_hall)

func _on_loader_body_entered(body, hall, backlink=false):
  if body.is_in_group("Player"):
    if backlink:
      _load_exhibit_from_entry(hall)
    else:
      _load_exhibit_from_exit(hall)

func _load_exhibit_from_entry(entry):
  var prev_article = Util.coalesce(entry.from_title, "Fungus")

  if entry.from_title == "$Lobby":
    _link_backlink_to_exit($Lobby, entry)
    return

  if _exhibits.has(prev_article):
    var exhibit = _exhibits[prev_article].exhibit
    if is_instance_valid(exhibit):
      _link_backlink_to_exit(exhibit, entry)
      return

  ExhibitFetcher.fetch([prev_article], {
    "title": prev_article,
    "backlink": true,
    "entry": entry,
  })

func _load_exhibit_from_exit(exit):
  var next_article = Util.coalesce(exit.to_title, "Fungus")

  # TODO: this needs to only work if the hall type matches
  if _exhibits.has(next_article):
    var next_exhibit = _exhibits[next_article]
    if (
      next_exhibit.has("entry") and
      next_exhibit.entry.hall_type[1] == exit.hall_type[1] and
      next_exhibit.entry.floor_type == exit.floor_type
    ):
      _link_halls(next_exhibit.entry, exit)
      next_exhibit.entry.from_title = exit.from_title
      return
    else:
      # TODO: erase orphaned backlinks
      _exhibits[next_article].exhibit.queue_free()
      _exhibits.erase(next_article)
      var i = _exhibit_hist.find(next_article)
      if i >= 0:
        _exhibit_hist.remove_at(i)

  ExhibitFetcher.fetch([next_article], {
    "title": next_article,
    "exit": exit
  })

func _add_item(exhibit, item_data):
  if not is_instance_valid(exhibit):
    return

  var slot = exhibit.get_item_slot()
  if slot == null:
    exhibit.add_room()
    if exhibit.has_item_slot():
      _add_item(exhibit, item_data)
    else:
      push_error("unable to add item slots to exhibit.")
    return

  var item = WallItem.instantiate()
  item.position = Util.gridToWorld(slot[0]) - slot[1] * 0.01
  item.rotation.y = Util.vecToRot(slot[1])

  # we use a delay to stop there from being a frame drop when a bunch of items are added at once
  # get_tree().create_timer(delay).timeout.connect(_init_item.bind(exhibit, item, item_data))
  _init_item(exhibit, item, item_data)

var text_item_fmt = "[color=black][b][font_size=200]%s[/font_size][/b]\n\n%s"

func _init_item(exhibit, item, data):
  if is_instance_valid(exhibit) and is_instance_valid(item):
    exhibit.add_child(item)
    item.init(data)

func _link_halls(entry, exit):
  for hall in [entry, exit]:
    Util.clear_listeners(hall, "on_player_toward_exit")
    Util.clear_listeners(hall, "on_player_toward_entry")

  _backlink_map[exit.to_title] = exit.from_title
  exit.on_player_toward_exit.connect(_teleport_player.bind(exit, entry))
  entry.on_player_toward_entry.connect(_teleport_player.bind(entry, exit, true))
  if exit.player_in_hall and exit.player_direction == "exit":
    _teleport_player(exit, entry)
  elif entry.player_in_hall and entry.player_direction == "entry":
    _teleport_player(entry, exit, true)

func _count_image_items(arr):
  var count = 0
  for i in arr:
    if i.has("type") and i.type == "image":
      count += 1
  return count

func _on_exit_added(exit, doors, backlink, new_exhibit, hall):
  var linked_exhibit = Util.coalesce(doors.pop_front(), "")
  exit.to_title = linked_exhibit
  exit.loader.body_entered.connect(_on_loader_body_entered.bind(exit))
  if is_instance_valid(hall) and backlink and exit.to_title == hall.to_title:
    _link_halls(hall, exit)

func _on_fetch_complete(_titles, context):
  # we don't need to do anything to handle a prefetch
  if context.has("prefetch"):
    return

  var backlink = context.has("backlink") and context.backlink
  var hall = context.entry if backlink else context.exit
  var result = ExhibitFetcher.get_result(context.title)
  if not result or not is_instance_valid(hall):
    # TODO: show an out of order sign
    return

  var prev_title
  if backlink:
    prev_title = _backlink_map[context.title]
  else:
    prev_title = hall.from_title

  ItemProcessor.create_items(context.title, result, prev_title)

  var data
  while not data:
    data = await ItemProcessor.items_complete
    if data.title != context.title:
      data = null

  var doors = data.doors
  var items = data.items
  var extra_text = data.extra_text

  _next_height += 20
  var new_exhibit = TiledExhibitGenerator.instantiate()
  add_child(new_exhibit)

  new_exhibit.exit_added.connect(_on_exit_added.bind(doors, backlink, new_exhibit, hall))
  new_exhibit.generate(_grid, {
    "start_pos": Vector3.UP * _next_height,
    "min_room_dimension": min_room_dimension,
    "max_room_dimension": max_room_dimension,
    "room_count": max(
      len(items) / items_per_room_estimate,
      min_rooms_per_exhibit
    ),
    "title": context.title,
    "prev_title": prev_title,
    "no_props": len(items) < 10,
    "hall_type": hall.hall_type,
    "exit_limit": len(doors),
  })

  if _count_image_items(items) < 3:
    var notice = NoImageNotice.instantiate()
    notice.rotation.y = Util.vecToRot(new_exhibit.entry.to_dir) - PI / 4
    notice.position = Util.gridToWorld(new_exhibit.entry.to_pos) + 5 * new_exhibit.entry.to_dir
    notice.position -= new_exhibit.entry.to_dir.rotated(Vector3.UP, PI / 2) * 2
    items.append_array(extra_text)
    extra_text = []
    new_exhibit.add_child(notice)

  if not _exhibits.has(context.title):
    _exhibits[context.title] = { "entry": new_exhibit.entry, "exhibit": new_exhibit, "height": _next_height }
    _exhibit_hist.append(context.title)
    if len(_exhibit_hist) > max_exhibits_loaded:
      for e in range(len(_exhibit_hist)):
        var key = _exhibit_hist[e]
        if _exhibits.has(key):
          var old_exhibit = _exhibits[key]
          if abs(4 * old_exhibit.height - _player.position.y) < 20:
            continue
          if old_exhibit.exhibit.title == new_exhibit.title:
            continue
          if OS.is_debug_build():
            print("erasing exhibit ", key)
          old_exhibit.exhibit.queue_free()
          _global_item_queue_map.erase(key)
          _exhibits.erase(key)
          _exhibit_hist.remove_at(e)
          break

  var image_titles = []
  var item_queue = []
  for item_data in items:
    if item_data.type == "image" and item_data.has("title") and item_data.title != "":
      image_titles.append(item_data.title)
    item_queue.append(_add_item.bind(new_exhibit, item_data))

  if result.has("wikidata_entity"):
    _queue_item_front(context.title, ExhibitFetcher.fetch_wikidata.bind(result.wikidata_entity, {
      "exhibit": new_exhibit,
      "title": context.title,
      "hall": hall,
      "backlink": backlink,
      "extra_text": extra_text
    }))

  _queue_item_front(context.title, ExhibitFetcher.fetch_images.bind(image_titles, null))
  _queue_item(context.title, item_queue)

  if backlink:
    new_exhibit.entry.loader.body_entered.connect(_on_loader_body_entered.bind(new_exhibit.entry, true))
  else:
    _link_halls(new_exhibit.entry, hall)

func _queue_extra_text(exhibit, extra_text):
  for item in extra_text:
    _queue_item(exhibit.title, _add_item.bind(exhibit, item))

func _link_backlink_to_exit(exhibit, hall):
  if not is_instance_valid(exhibit) or not is_instance_valid(hall):
    return

  var new_hall
  for exit in exhibit.exits:
    if exit.to_title == hall.to_title:
      new_hall = exit
      break
  if not new_hall and exhibit.entry:
    push_error("could not backlink new hall")
    new_hall = exhibit.entry
  if new_hall:
    _link_halls(hall, new_hall)

func _on_wikidata_complete(entity, ctx):
  var result = ExhibitFetcher.get_result(entity)
  if result and (result.has("commons_category") or result.has("commons_gallery")):
    if result.has("commons_category"):
      ExhibitFetcher.fetch_commons_images(result.commons_category, ctx)
    if result.has("commons_gallery"):
      ExhibitFetcher.fetch_commons_images(result.commons_gallery, ctx)
  else:
    _queue_extra_text(ctx.exhibit, ctx.extra_text)
    _queue_item(ctx.title, _on_finished_exhibit.bind(ctx))

func _on_commons_images_complete(images, ctx):
  if len(images) > 0:
    var item_data = ItemProcessor.commons_images_to_items(ctx.title, images, ctx.extra_text)
    for item in item_data:
      _queue_item(ctx.title, _add_item.bind(
        ctx.exhibit,
        item
      ))
  # for now we do not add all the remaining text if a commons category is present
  #_queue_extra_text(ctx.exhibit, ctx.extra_text)
  _queue_item(ctx.title, _on_finished_exhibit.bind(ctx))

func _on_finished_exhibit(ctx):
  if not is_instance_valid(ctx.exhibit):
    return
  if OS.is_debug_build():
    print("finished exhibit. slots=", len(ctx.exhibit._item_slots))
  if ctx.backlink:
    _link_backlink_to_exit(ctx.exhibit, ctx.hall)

var _queue_running = false
var _global_item_queue_map = {}

func _process_item_queue():
  var queue = _global_item_queue_map.get(_current_room_title, [])
  var callable = queue.pop_front()
  if not callable:
    _queue_running = false
    return
  else:
    _queue_running = true
    callable.call()
    get_tree().create_timer(QUEUE_DELAY).timeout.connect(_process_item_queue.bind())

func _queue_item_front(title, item):
  _queue_item(title, item, true)

func _queue_item(title, item, front = false):
  if not _global_item_queue_map.has(title):
    _global_item_queue_map[title] = []
  if typeof(item) == TYPE_ARRAY:
    _global_item_queue_map[title].append_array(item)
  elif not front:
    _global_item_queue_map[title].append(item)
  else:
    _global_item_queue_map[title].push_front(item)
  _start_queue()

func _start_queue():
  if not _queue_running:
    _process_item_queue()

@export var max_teleport_distance: float = 10.0
@export var max_exhibits_loaded: int = 2
@export var min_room_dimension: int = 2
@export var max_room_dimension: int = 5
