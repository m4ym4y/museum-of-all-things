extends Node3D

@onready var LoaderTrigger = preload("res://scenes/LoaderTrigger.tscn")
@onready var TiledExhibitGenerator = preload("res://scenes/TiledExhibitGenerator.tscn")
@onready var DEFAULT_DOORS = [
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

# item types
@onready var WallItem = preload("res://scenes/items/WallItem.tscn")
@onready var IMAGE_REGEX = RegEx.new()
@onready var _xr = Util.is_xr()

@onready var _fetcher = $ExhibitFetcher
@onready var _exhibit_hist = []
@onready var _exhibits = {}
@onready var _backlink_map = {}
@onready var _text_map = {}
@onready var _next_height = 20
@onready var _current_room_title = "Lobby"
var _grid
var _player

func _init():
	RenderingServer.set_debug_generate_wireframes(true)

func init(player):
	_player = player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	IMAGE_REGEX.compile("\\.(png|jpg|jpeg)$")

	$WorldEnvironment.environment.ssr_enabled = not _xr

	_grid = $Lobby/GridMap
	_fetcher.fetch_complete.connect(_on_fetch_complete)
	_set_up_lobby($Lobby)

func _set_up_lobby(lobby):
	var exits = lobby.exits
	_exhibits["$Lobby"] = lobby

	print("Setting up lobby with %s exits..." % len(exits))

	for exit in exits:
		var title = DEFAULT_DOORS.pop_front()
		if not title:
			break
		exit.to_title = title
		exit.loader.body_entered.connect(_on_loader_body_entered.bind(exit))

func set_up_exhibit(exhibit, room_count=default_room_count, title="Lobby", prev_title="Lobby", _min_room_dimension=min_room_dimension, _max_room_dimension=max_room_dimension):
	var generated_results = exhibit.generate(
			_grid,
			Vector3(0, _next_height, 0),
			_min_room_dimension,
			_max_room_dimension,
			room_count,
			title,
			prev_title,
	)

	var entry = generated_results.entry
	var exits = generated_results.exits

	# add a marker at every exit
	for exit in exits:
		exit.loader.body_entered.connect(_on_loader_body_entered.bind(exit))

	return generated_results

func _set_current_room_title(title):
	_current_room_title = title
	
	$Speaker.stop()
	get_tree().create_timer(3.0).timeout.connect(_speak_current_page)
	
	var fog_color = Util.gen_fog(_current_room_title)
	var environment = $WorldEnvironment.environment
	
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
	# print("teleport. from=%s to=%s" % [from_hall.from_title, to_hall.to_title])
	if is_instance_valid(from_hall) and is_instance_valid(to_hall):
		var pos = _player.global_position if not _xr else _player.get_node("XRCamera3D").global_position
		var distance = (from_hall.position - pos).length()
		if distance > max_teleport_distance:
			print("distance=%s max=%s" % [distance, max_teleport_distance])
			return
		var diff_from = _player.global_position - from_hall.position
		var rot_diff = Util.vecToRot(to_hall.to_dir) - Util.vecToRot(from_hall.to_dir)
		_player.global_position = to_hall.position + diff_from.rotated(Vector3(0, 1, 0), rot_diff)
		_player.global_rotation.y += rot_diff
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

func _speak_current_page():
	if _text_map.has(_current_room_title):
		$Speaker.speak(_text_map[_current_room_title])

func _on_loader_body_entered(body, exit):
	if body.is_in_group("Player"):
		_load_exhibit_from_exit(exit)

func _load_exhibit_from_entry(entry):
	var prev_article = Util.coalesce(entry.from_title, "Fungus")

	# TODO: relink portals so we don't need this block
	if _exhibits.has(prev_article):
		push_error("loading from entry even though prev article was unloaded?")
		return

	_fetcher.fetch([prev_article], {
		"title": prev_article,
		"backlink": true,
		"entry": entry,
	})

func _load_exhibit_from_exit(exit):
	var next_article = Util.coalesce(exit.to_title, "Fungus")

	if _exhibits.has(next_article):
		var next_exhibit = _exhibits[next_article]
		if next_exhibit.has("entry") and exit.player_in_hall and exit.player_direction == "exit":
			var entry = next_exhibit.entry
			_teleport_player(entry, exit)
		return

	_fetcher.fetch([next_article], {
		"title": next_article,
		"exit": exit
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

func _add_item(exhibit, slots, item_data):
	var slot = slots.pop_front()
	if slot == null:
		return

	var item = WallItem.instantiate()
	item.position = Util.gridToWorld(slot[0]) - slot[1] * 0.01
	item.rotation.y = Util.vecToRot(slot[1])

	# we use a delay to stop there from being a frame drop when a bunch of items are added at once
	# get_tree().create_timer(delay).timeout.connect(_init_item.bind(exhibit, item, item_data))
	_init_item(exhibit, item, item_data)

func _result_to_exhibit_data(title, result):
	var items = []
	var doors = []

	if result:
		if result.has("extract"):
			_text_map[title] = result.extract
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
						"text": Util.coalesce(image.text, image.src.split("/")[-1].uri_decode()),
					})

	return {
		"doors": doors,
		"items": items,
	}

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

func _on_fetch_complete(_titles, context):
	# we don't need to do anything to handle a prefetch
	if context.has("prefetch"):
		return

	var backlink = context.has("backlink") and context.backlink
	var hall = context.entry if backlink else context.exit
	var result = _fetcher.get_result(context.title)
	if not result or not is_instance_valid(hall):
		# TODO: show an out of order sign
		return

	var data = _result_to_exhibit_data(context.title, result)
	var doors = data.doors
	var items = data.items

	var prev_title
	if backlink:
		prev_title = _backlink_map[context.title]
	else:
		prev_title = hall.from_title

	_next_height += 20
	var new_exhibit = TiledExhibitGenerator.instantiate()
	add_child(new_exhibit)

	set_up_exhibit(
		new_exhibit,
		max(len(items) / 10, 2),
		context.title,
		prev_title
	)

	var exits = new_exhibit.exits
	var slots = new_exhibit.item_slots
	var linked_exhibits = []

	# fill in doors out of the exhibit
	for e in exits:
		var linked_exhibit = Util.coalesce(doors.pop_front(), "")
		e.to_title = linked_exhibit
		linked_exhibits.append(linked_exhibit)

	var new_hall
	if backlink:
		for exit in new_exhibit.exits:
			if exit.to_title == hall.to_title:
				new_hall = exit
				break
		if not new_hall:
			push_error("could not backlink new hall")
			new_hall = new_exhibit.entry
	else:
		new_hall = new_exhibit.entry

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
					if abs(4 * old_exhibit.height - new_hall.position.y) < 20:
						continue
					print("erasing exhibit ", key)
					old_exhibit.exhibit.queue_free()
					_exhibits.erase(key)
					_exhibit_hist.remove_at(e)
					break

	var item_queue = []
	for item_data in items:
		item_queue.append(_add_item.bind(new_exhibit, slots, item_data))
	_process_item_queue(item_queue, 0.1)

	if backlink:
		_link_halls(hall, new_hall)
	else:
		_link_halls(new_hall, hall)

func _process_item_queue(queue, delay):
	var callable = queue.pop_front()
	if not callable:
		return
	else:
		callable.call()
		get_tree().create_timer(delay).timeout.connect(_process_item_queue.bind(queue, delay))

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

@export var max_teleport_distance: float = 10.0
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
