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
@onready var _xr = Util.is_xr()

@onready var _fetcher = $ExhibitFetcher
@onready var _exhibit_hist = []
@onready var _exhibits = {}
@onready var _backlink_map = {}
@onready var _next_height = 0
var _grid
var _player

@onready var _entry_portal
@onready var _exit_portal

func _init():
	RenderingServer.set_debug_generate_wireframes(true)

func init(player):
	_player = player

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

		if not _xr:
			_entry_portal = Portal.instantiate()
			_exit_portal = Portal.instantiate()
			_entry_portal.exit_portal = _exit_portal
			_exit_portal.exit_portal = _entry_portal
			add_child(_entry_portal)
			add_child(_exit_portal)

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

	# _entry_portal.rotation.y = Util.vecToRot(entry.to_dir) + PI
	# _entry_portal.position = Util.gridToWorld(entry.to_pos) + Vector3(0, 1.5, 0)

	# add a marker at every exit
	for exit in exits:
		exit.loader.body_entered.connect(_on_loader_body_entered.bind(exit))

	return generated_results

func _teleport_player(from_hall, to_hall):
	var diff_from = _player.position - from_hall.position
	var rot_diff = Util.vecToRot(to_hall.to_dir) - Util.vecToRot(from_hall.to_dir)
	print("diff=%s rot=%s pos=%s to_pos=%s from_pos=%s to=%s" % [diff_from, rot_diff, _player.position, to_hall.position, from_hall.position, from_hall.to_label.text])
	_player.position = to_hall.position + diff_from.rotated(Vector3(0, 1, 0), rot_diff)
	_player.rotation.y += rot_diff

func _link_portals(entry, exit, reverse=false):
	if not _xr:
		if is_instance_valid(entry) and is_instance_valid(exit):
			_backlink_map[exit.to_label.text] = exit.from_label.text
			if reverse:
				_exit_portal.rotation.y = Util.vecToRot(exit.from_dir)
				_exit_portal.position = Util.gridToWorld(exit.from_pos) + Vector3(0, 1.5, 0)
				_entry_portal.position = Util.gridToWorld(entry.from_pos) + Vector3(0, 1.5, 0)
				_entry_portal.rotation.y = Util.vecToRot(entry.from_dir) + PI
			else:
				_exit_portal.rotation.y = Util.vecToRot(exit.to_dir)
				_exit_portal.position = Util.gridToWorld(exit.to_pos) + Vector3(0, 1.5, 0)
				_entry_portal.position = Util.gridToWorld(entry.to_pos) + Vector3(0, 1.5, 0)
				_entry_portal.rotation.y = Util.vecToRot(entry.to_dir) + PI
		elif is_instance_valid(exit):
			# TODO: does this happen?
			# _load_body_from_exit(exit, reverse)
			pass
		elif is_instance_valid(entry):
			_load_body_from_entry(entry)

func _on_loader_body_entered(body, exit):
	if body.is_in_group("Player"):
		_load_body_from_exit(exit)

func _load_body_from_entry(entry):
	var prev_article = Util.coalesce(entry.from_label.text, "Fungus")

	# TODO: relink portals so we don't need this block
	if _exhibits.has(prev_article):
		push_error("loading from entry even though prev article was unloaded?")
		return

	_fetcher.fetch([prev_article], {
		"title": prev_article,
		"backlink": true,
		"entry": entry,
	})

func _load_body_from_exit(exit):
	var next_article = Util.coalesce(exit.to_label.text, "Fungus")

	if _exhibits.has(next_article):
		var next_exhibit = _exhibits[next_article]
		if next_exhibit.has("entry") and exit.player_in_hall:
			var entry = next_exhibit.entry
			_link_portals(entry, exit)
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

	var backlink = context.has("backlink") and context.backlink
	var hall = context.entry if backlink else context.exit
	var result = _fetcher.get_result(context.title)
	if not result:
		# TODO: show an out of order sign
		return

	var data = _result_to_exhibit_data(context.title, result)
	var doors = data.doors
	var items = data.items

	var prev_title
	if backlink:
		prev_title = _backlink_map[context.title]
	else:
		prev_title = hall.from_label.text

	_next_height += 20
	var new_exhibit = TiledExhibitGenerator.instantiate()
	add_child(new_exhibit)
	set_up_exhibit(
		new_exhibit,
		max(len(items) / 6, 1),
		context.title,
		prev_title
	)

	var exits = new_exhibit.exits
	var slots = new_exhibit.item_slots
	var linked_exhibits = []

	# fill in doors out of the exhibit
	for e in exits:
		var linked_exhibit = Util.coalesce(doors.pop_front(), "")
		e.to_label.text = linked_exhibit
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

	var new_hall
	if backlink:
		for exit in new_exhibit.exits:
			if exit.to_label.text == hall.to_label.text:
				new_hall = exit
				break
		if not new_hall:
			push_error("could not backlink new hall")
			new_hall = new_exhibit.entry
	else:
		new_hall = new_exhibit.entry

	Util.clear_listeners(hall, "on_player_in_hall")
	Util.clear_listeners(new_hall, "on_player_in_hall")
	
	if not _xr:
		if hall.player_in_hall:
			if backlink:
				_link_portals(hall, new_hall, true)
			else:
				_link_portals(new_hall, hall)
		else:
			if backlink:
				hall.on_player_in_hall.connect(_link_portals.bind(hall, new_hall, true))
				new_hall.on_player_in_hall.connect(_link_portals.bind(hall, new_hall))
			else:
				hall.on_player_in_hall.connect(_link_portals.bind(new_hall, hall))
				new_hall.on_player_in_hall.connect(_link_portals.bind(new_hall, hall, true))
	else:
		if not hall.player_in_hall:
			hall.on_player_in_hall.connect(_teleport_player.bind(hall, new_hall))

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
					old_exhibit.exhibit.queue_free()
					_exhibits.erase(key)
					_exhibit_hist.remove_at(e)
					break

	if backlink:
		hall.entry_door.open()
	else:
		hall.exit_door.open()

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
