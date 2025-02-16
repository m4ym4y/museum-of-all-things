extends Node3D

@onready var hall_scene = preload("res://scenes/Hall.tscn")
@onready var _grid = $GridMap
@onready var exits = []
@onready var entry = null
@onready var _rng = RandomNumberGenerator.new()

const FLOOR_WOOD = 0
const FLOOR_CARPET = 11
const FLOOR_MARBLE = 12

const INTERNAL_HALL = 7
const DIRECTIONS = [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
const FLOORS = [FLOOR_WOOD, FLOOR_MARBLE, FLOOR_CARPET]

func _get_hall_dir(pos):
	var p = pos - Vector3.UP
	var ori = _grid.get_cell_item_orientation(pos)
	var dirs = []

	if ori == 0 or ori == 10:
		dirs = [Vector3.FORWARD, Vector3.BACK]
	elif ori == 16 or ori == 22:
		dirs = [Vector3.LEFT, Vector3.RIGHT]

	for dir in dirs:
		var cell = p + dir
		if FLOORS.has(_grid.get_cell_item(cell)):
			return -dir

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalGridAccess.set_grid(_grid)
	_rng.seed = hash("$Lobby")
	for cell_pos in _grid.get_used_cells():
		var c = Vector3(cell_pos)
		if _grid.get_cell_item(c) == INTERNAL_HALL:
			var hall_dir = _get_hall_dir(c)
			if not hall_dir:
				continue
			var hall = hall_scene.instantiate()
			add_child(hall)
			hall.init(_grid, "$Lobby", "$Lobby", c, hall_dir, [true, _rng.randi_range(-1, 1)])
			exits.append(hall)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
