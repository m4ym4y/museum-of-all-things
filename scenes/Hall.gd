extends Node3D
class_name Hall

signal on_player_toward_exit
signal on_player_toward_entry

@onready var grid_wrapper = preload("res://scenes/util/GridWrapper.tscn")
@onready var loader = $LoaderTrigger
@onready var entry_door = $EntryDoor
@onready var exit_door = $ExitDoor
@onready var _detector = $HallDirectionDetector

@onready var from_sign = $FromSign
@onready var to_sign = $ToSign
@onready var floor_type

static var WALL = 5
static var INTERNAL_HALL = 7
static var INTERNAL_HALL_TURN = 6
static var HALL_STAIRS_UP = 16
static var HALL_STAIRS_DOWN = 17
static var HALL_STAIRS_TURN = 18

var _grid
var hall_type

var player_direction
var player_in_hall: bool:
	get:
		return _detector.player or false
	set(_value):
		pass

var from_title: String:
	get:
		return from_sign.text
	set(v):
		from_sign.text = v

var from_pos
var from_dir

var to_title: String:
	get:
		return to_sign.text
	set(v):
		to_sign.text = v

var to_pos
var to_dir

static var UP = 1
static var FLAT = 0
static var DOWN = -1

static func valid_hall_types(grid, hall_start, hall_dir):
	var hall_corner = hall_start + hall_dir

	var hall_dir_right = hall_dir.rotated(Vector3.UP, 3 * PI / 2)
	var hall_exit_right = hall_corner + hall_dir_right
	var past_hall_exit_right = hall_corner + 2 * hall_dir_right

	var hall_dir_left = hall_dir.rotated(Vector3.UP, PI / 2)
	var hall_exit_left = hall_corner + hall_dir_left
	var past_hall_exit_left = hall_corner + 2 * hall_dir_left

	var corner_cell_down = grid.get_cell_item(hall_corner - Vector3.UP)
	var corner_empty_neighbors = Util.cell_neighbors(grid, hall_corner - Vector3.UP, -1)

	if (
		not Util.safe_overwrite(grid, hall_corner) or
		len(corner_empty_neighbors) != 4
	):
		return []

	var valid_halls = []

	if (
		not (
			grid.get_cell_item(past_hall_exit_right - Vector3.UP) != -1 and
			grid.get_cell_item(past_hall_exit_right) == -1
		) and
		not (
			grid.get_cell_item(past_hall_exit_right - Vector3.UP) == 1 and
			grid.get_cell_item(past_hall_exit_right) == 1
		) and
		Util.safe_overwrite(grid, hall_exit_right)
	):
		valid_halls.append([true, FLAT])
		valid_halls.append([true, UP])
		valid_halls.append([true, DOWN])

	# let's just comment this out until left halls work...
	"""
	if (
		not (
			grid.get_cell_item(past_hall_exit_left - Vector3.UP) != -1 and
			grid.get_cell_item(past_hall_exit_left) == -1
		) and
		Util.safe_overwrite(grid, hall_exit_left)
	):
		valid_halls.append([false, FLAT])
		valid_halls.append([false, UP])
		valid_halls.append([false, DOWN])
	"""

	return valid_halls

func create_curve_hall(hall_start, hall_dir, is_right=true, level=FLAT):
	var ori = Util.vecToOrientation(_grid, hall_dir)
	var ori_turn = Util.vecToOrientation(_grid, hall_dir.rotated(Vector3.UP, 3 * PI / 2))
	var corner_ori = ori if is_right else ori_turn
	var hall_corner = hall_start + hall_dir

	if level == FLAT:
		_grid.set_cell_item(hall_start, INTERNAL_HALL, ori)
		_grid.set_cell_item(hall_start - Vector3.UP, floor_type, 0)
		_grid.set_cell_item(hall_start + Vector3.UP, WALL, 0)
		_grid.set_cell_item(hall_corner, INTERNAL_HALL_TURN, corner_ori)
		_grid.set_cell_item(hall_corner - Vector3.UP, floor_type, 0)
		$Light.global_position = Util.gridToWorld(hall_corner) + Vector3.UP * 2
	elif level == UP:
		_grid.set_cell_item(hall_start, HALL_STAIRS_UP, ori)
		_grid.set_cell_item(hall_start + Vector3.UP, -1, ori)
		_grid.set_cell_item(hall_corner + Vector3.UP, -1, ori)
		_grid.set_cell_item(hall_corner, HALL_STAIRS_TURN, corner_ori)
		$Light.global_position = Util.gridToWorld(hall_corner) + Vector3.UP * 4
	elif level == DOWN:
		_grid.set_cell_item(hall_start, HALL_STAIRS_DOWN, ori)
		_grid.set_cell_item(hall_start + Vector3.UP, -1, ori)
		_grid.set_cell_item(hall_corner, -1, ori)
		_grid.set_cell_item(hall_corner - Vector3.UP, HALL_STAIRS_TURN, corner_ori)
		$Light.global_position = Util.gridToWorld(hall_corner)

	var exit_hall_dir = hall_dir.rotated(Vector3.UP, (3 if is_right else 1) * PI / 2)
	var exit_hall = hall_corner + exit_hall_dir
	var exit_ori = Util.vecToOrientation(_grid, exit_hall_dir)
	var exit_ori_neg = Util.vecToOrientation(_grid, -exit_hall_dir)

	to_dir = exit_hall_dir

	if level == FLAT:
		_grid.set_cell_item(exit_hall, INTERNAL_HALL, exit_ori)
		_grid.set_cell_item(exit_hall - Vector3.UP, floor_type, 0)
		_grid.set_cell_item(exit_hall + Vector3.UP, WALL, 0)
		to_dir = exit_hall_dir
		to_pos = exit_hall
	elif level == UP:
		_grid.set_cell_item(exit_hall + Vector3.UP, HALL_STAIRS_DOWN, exit_ori_neg)
		_grid.set_cell_item(exit_hall + 2 * Vector3.UP, -1, 0)
		_grid.set_cell_item(exit_hall, -1, 0)
		_grid.set_cell_item(exit_hall - Vector3.UP, -1, 0)
		to_pos = exit_hall + Vector3.UP
	elif level == DOWN:
		_grid.set_cell_item(exit_hall - Vector3.UP, HALL_STAIRS_UP, exit_ori_neg)
		_grid.set_cell_item(exit_hall, -1, 0)
		_grid.set_cell_item(exit_hall + Vector3.UP, -1, 0)
		to_pos = exit_hall - Vector3.UP

func init(grid, from_title, to_title, hall_start, hall_dir, _hall_type=[true, FLAT]):
	floor_type = Util.gen_floor(from_title)
	position = Util.gridToWorld(hall_start)
	loader.monitoring = true

	_grid = grid_wrapper.instantiate()
	_grid.init(grid)
	add_child(_grid)

	hall_type = _hall_type
	create_curve_hall(hall_start, hall_dir, hall_type[0], hall_type[1])

	from_dir = hall_dir
	from_pos = hall_start

	from_sign.position = Util.gridToWorld(to_pos + to_dir * 0.65) - position
	from_sign.position += to_dir.rotated(Vector3.UP, PI / 2).normalized() * 1.5
	from_sign.rotation.y = Util.vecToRot(to_dir) + 3 * PI / 4
	from_sign.text = from_title
	from_sign.visible = false

	to_sign.position = Util.gridToWorld(hall_start - hall_dir * 0.60) - position
	to_sign.position -= hall_dir.rotated(Vector3.UP, PI / 2).normalized() * 1.5
	to_sign.rotation.y = Util.vecToRot(hall_dir) - PI / 4
	to_sign.text = to_title

	entry_door.position = Util.gridToWorld(from_pos) - 1.9 * from_dir - position
	entry_door.rotation.y = Util.vecToRot(from_dir) + PI
	exit_door.position = Util.gridToWorld(to_pos) + 1.9 * to_dir - position
	exit_door.rotation.y = Util.vecToRot(to_dir)
	entry_door.set_open(true, true)
	exit_door.set_open(false, true)

	var center_pos = Util.gridToWorld((from_pos + to_pos) / 2) + Vector3(0, 4, 0) - position

	_detector.position = center_pos
	_detector.monitoring = true
	_detector.direction_changed.connect(_on_direction_changed)
	_detector.init(Util.gridToWorld(from_pos), Util.gridToWorld(to_pos))

	loader.position = center_pos

	ExhibitFetcher.wikitext_failed.connect(_on_fetch_failed)

func _on_fetch_failed(titles, message):
	for title in titles:
		if title == to_title:
			exit_door.set_message("Error Loading Exhibit: " + message)

func _on_direction_changed(direction):
	player_direction = direction
	if direction == "exit":
		emit_signal("on_player_toward_exit")
	else:
		emit_signal("on_player_toward_entry")
