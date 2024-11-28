@tool
extends Node3D

@onready var pool_scene = preload("res://scenes/items/Pool.tscn")
@onready var hall = preload("res://scenes/Hall.tscn")
@onready var grid_wrapper = preload("res://scenes/util/GridWrapper.tscn")

@onready var _rng
@onready var _title
@onready var _prev_title

var entry
var exits = []
var item_slots = []
var _raw_grid
var _grid
var _floor

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	pass

func cell_neighbors(pos, id):
	var neighbors = []
	for x in range(-1, 2):
		for z in range(-1, 2):
			# no diagonals
			if x != 0 and z != 0:
				continue
			elif x == 0 and z == 0:
				continue

			var vec = Vector3(pos.x + x, pos.y, pos.z + z)
			var cell_val = _grid.get_cell_item(vec)

			if cell_val == id:
				neighbors.append(vec)
	return neighbors

const FLOOR_WOOD = 0
const FLOOR_CARPET = 11
const FLOOR_MARBLE = 12

const WALL = 5
const CEILING = 3
const INTERNAL_HALL = 7
const INTERNAL_HALL_TURN = 6
const MARKER = 8
const BENCH = 9
const FREE_WALL = 10

const DIRECTIONS = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]

func rand_dir():
	return DIRECTIONS[_rng.randi() % len(DIRECTIONS)]

func vlt(v1, v2):
	return v1 if v1.x < v2.x or v1.z < v2.z else v2

func vgt(v1, v2):
	return v1 if v1.x > v2.x or v1.z > v2.z else v2

func vec_key(v):
	return var_to_bytes(v)

func generate(
		grid,
		start_pos,
		min_room_dimension,
		max_room_dimension,
		room_count,
		title,
		prev_title,
	):
	_raw_grid = grid
	_grid = grid_wrapper.instantiate()
	_grid.init(_raw_grid)
	add_child(_grid)

	_rng = RandomNumberGenerator.new()
	_rng.seed = hash(title)
	_title = title
	_prev_title = prev_title
	_floor = Util.gen_floor(title)

	var rand_dim = func() -> int:
		return _rng.randi_range(min_room_dimension, max_room_dimension)

	var starting_hall = hall.instantiate()
	add_child(starting_hall)
	starting_hall.init(
		_raw_grid,
		prev_title,
		title,
		start_pos,
		Vector3(1, 0, 0)
	)

	starting_hall.entry_door.set_open(false, true)
	starting_hall.exit_door.open()

	entry = starting_hall
	exits = []
	item_slots = []

	var room_width = rand_dim.call()
	var room_length = rand_dim.call()
	var room_center = Vector3(
		starting_hall.to_pos.x + starting_hall.to_dir.x * (2 + room_width / 2),
		start_pos.y,
		starting_hall.to_pos.z + starting_hall.to_dir.z * (2 + room_length / 2),
	) - starting_hall.to_dir

	var next_room_direction
	var next_room_width
	var next_room_length
	var next_room_center

	var room_list = {}
	var branch_point_list = []
	var room_entry

	while room_list.size() < room_count:
		room_entry = {
			"center": room_center,
			"width": room_width,
			"length": room_length
		}
		branch_point_list.append(room_entry)
		room_list[vec_key(room_center)] = room_entry

		var bounds = room_to_bounds(room_center, room_width, room_length)
		carve_room(bounds[0], bounds[1], start_pos.y)

		var early_terminate = true

		# sometimes just throw in branches to keep em guessing
		if len(branch_point_list) < 3 or _rng.randi() % 4 != 0:
			for nop_ in range(50):
				next_room_direction = rand_dir()
				next_room_width = rand_dim.call()
				next_room_length = rand_dim.call()
				next_room_center = room_center + Vector3(
					next_room_direction.x * (room_width / 2 + next_room_width / 2 + 3),
					0,
					next_room_direction.z * (room_length / 2 + next_room_length / 2 + 3)
				)

				var new_bounds = room_to_bounds(next_room_center, next_room_width, next_room_length)
				if not overlaps_room(new_bounds[0], new_bounds[1], start_pos.y):
					early_terminate = false
					break

		if early_terminate:
			branch_point_list.pop_back()
			var prev_room = branch_point_list.pop_back()
			if prev_room == null:
				break

			room_center = prev_room["center"]
			room_width = prev_room["width"]
			room_length = prev_room["length"]
			continue

		if room_list.size() < room_count:
			var start_hall = vlt(room_center, next_room_center)
			var end_hall = vgt(room_center, next_room_center)
			var hall_width
			var start_hall_offset
			var end_hall_offset

			if (start_hall - end_hall).x != 0:
				hall_width = _rng.randi_range(1, min(room_length, next_room_length))
				start_hall -= Vector3(0, 0, hall_width / 2)
				end_hall += Vector3(0, 0, (hall_width - 1) / 2)
			else:
				hall_width = _rng.randi_range(1, min(room_width, next_room_width))
				start_hall -= Vector3(hall_width / 2, 0, 0)
				end_hall += Vector3((hall_width - 1) / 2, 0, 0)

			carve_room(
					start_hall,
					end_hall,
					start_pos.y
			)

		room_center = next_room_center
		room_width = next_room_width
		room_length = next_room_length

	# add the final room
	# TODO: restructure the whole weird-ass loop here
	room_list[vec_key(room_entry.center)] = room_entry

	# ignore starting hall
	for room in room_list.values():
		decorate_room(room)

	return {
		"entry": entry,
		"exits": exits
	}

func decorate_room(room):
	var center = room.center
	var width = room.width
	var length = room.length

	if !Engine.is_editor_hint():
		decorate_room_center(center, width, length)

	var bounds = room_to_bounds(center, width, length)
	var c1 = bounds[0]
	var c2 = bounds[1]
	var y = center.y

	# walk border of room to place wall objects
	for x in range(c1.x, c2.x + 1):
		for z in [c1.z, c2.z]:
			decorate_wall_tile(Vector3(x, y, z))
	for z in range(c1.z, c2.z + 1):
		for x in [c1.x, c2.x]:
			decorate_wall_tile(Vector3(x, y, z))

func decorate_room_center(center, width, length):
	if width > 3 and length > 3 and _rng.randi_range(0, 2) == 0:
		var pool = pool_scene.instantiate()
		var bounds = room_to_bounds(center, width, length)
		var true_center = (bounds[0] + bounds[1]) / 2
		pool.position = Util.gridToWorld(true_center)
		add_child(pool)
		return

	var bench_area_bounds = null
	var bench_area_ori = 0
	if width > length and width > 2:
		bench_area_bounds = room_to_bounds(center, width - 2, 1)
	elif length > width and length > 2:
		bench_area_ori = Util.vecToOrientation(_grid, Vector3(1, 0, 0))
		bench_area_bounds = room_to_bounds(center, 1, length - 2)
	if bench_area_bounds:
		var c1 = bench_area_bounds[0]
		var c2 = bench_area_bounds[1]
		var y = center.y
		for x in range(c1.x, c2.x + 1):
			for z in range(c1.z, c2.z + 1):
				var pos = Vector3(x, y, z)
				var free_wall = _rng.randi_range(0, 1) == 0
				if width > 3 or length > 3 and free_wall:
					var dir = Vector3.RIGHT if width > length else Vector3.FORWARD
					var item_dir = Vector3.FORWARD if width > length else Vector3.RIGHT
					var ori = Util.vecToOrientation(_grid, dir)
					_grid.set_cell_item(pos, FREE_WALL, ori)
					item_slots.append([pos - item_dir * 0.075, item_dir])
					item_slots.append([pos + item_dir * 0.075, -item_dir])
				else:
					_grid.set_cell_item(pos, BENCH, bench_area_ori)

func decorate_wall_tile(pos):
	# grid.set_cell_item(pos + Vector3(0, 2, 0), MARKER, 0)

	var wall_neighbors = cell_neighbors(pos, WALL)
	for wall in wall_neighbors:
		var slot = (wall + pos) / 2
		var hall_dir = wall - pos
		var hall_corner = wall + hall_dir
		var hall_exit_dir = hall_dir.rotated(Vector3.UP, 3 * PI / 2)
		var past_hall_exit = hall_corner + 2 * hall_exit_dir

		# put an exit everywhere it fits
		if (
				_grid.get_cell_item(hall_corner - Vector3(0, 1, 0)) == -1 and
				not (
					_grid.get_cell_item(past_hall_exit - Vector3.UP) != -1 and
					_grid.get_cell_item(past_hall_exit) == -1
				) and
				len(cell_neighbors(hall_corner - Vector3(0, 1, 0), -1)) == 4
		):
			var new_hall = hall.instantiate()
			add_child(new_hall)
			new_hall.init(
				_raw_grid,
				_title,
				_title,
				wall,
				hall_dir
			)

			exits.append(new_hall)
		# put exhibit items everywhere else
		else:
			var is_dupe = false
			for item_slot in item_slots:
				if item_slot[0].is_equal_approx(slot):
					is_dupe = true
			if not is_dupe:
				item_slots.append([slot, hall_dir])

func room_to_bounds(center, width, length):
	return [
		Vector3(center.x - width / 2, center.y, center.z - length / 2),
		Vector3(center.x + width / 2 - ((width + 1) % 2), center.y, center.z + length / 2 + ((length + 1) % 2))
	]

func carve_room(corner1, corner2, y):
	var lx = corner1.x
	var gx = corner2.x
	var lz = corner1.z
	var gz = corner2.z
	for x in range(lx - 1, gx + 2):
		for z in range(lz - 1, gz + 2):
			if x < lx or z < lz or x > gx or z > gz:
				if _grid.get_cell_item(Vector3(x, y - 1, z)) == -1:
					_grid.set_cell_item(Vector3(x, y, z), WALL, 0)
					_grid.set_cell_item(Vector3(x, y + 1, z), WALL, 0)
					_grid.set_cell_item(Vector3(x, y + 2, z), -1, 0)
				elif _grid.get_cell_item(Vector3(x, y, z)) == INTERNAL_HALL:
					_grid.set_cell_item(Vector3(x, y + 1, z), WALL, 0)
			else:
				_grid.set_cell_item(Vector3(x, y, z), -1, 0)
				_grid.set_cell_item(Vector3(x, y + 1, z), -1, 0)
				_grid.set_cell_item(Vector3(x, y + 2, z), CEILING, 0)
				_grid.set_cell_item(Vector3(x, y - 1, z), _floor, 0)

func overlaps_room(corner1, corner2, y):
	for x in range(corner1.x - 1, corner2.x + 2):
		for z in range(corner1.z - 1, corner2.z + 2):
			var cell = _grid.get_cell_item(Vector3(x, y - 1, z))
			if cell != -1:
				return true
	return false
