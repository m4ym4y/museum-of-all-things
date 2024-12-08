extends Node

@onready var _grid
@onready var _cells_set = []
@onready var _reserved_zones = []

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		_on_free()

func _on_free():
	if not is_instance_valid(_grid):
		return

	for cell in _cells_set:
		# dont reset an overwritten cell
		if _grid.get_cell_item(cell[0]) == cell[1]:
			_grid.set_cell_item(cell[0], -1, 0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func init(grid):
	_grid = grid

func set_cell_item(pos, val, ori):
	_cells_set.append([pos, val])
	_grid.set_cell_item(pos, val, ori)

func get_cell_item(pos):
	for zone in _reserved_zones:
		if is_in_zone(pos, zone):
			return RESERVED_VAL
	return _grid.get_cell_item(pos)

func get_orthogonal_index_from_basis(basis):
	return _grid.get_orthogonal_index_from_basis(basis)

const RESERVED_VAL = 1
func reserve_zone(zone):
	_reserved_zones.append(zone)

func free_reserved_zone(p):
	var z = 0
	while z < len(_reserved_zones):
		var zone = _reserved_zones[z]
		if is_in_zone(p, zone):
			_reserved_zones.remove_at(z)
			z -= 1
		z += 1

func is_in_zone(p, zone):
	return p.x >= zone[0].x and p.x <= zone[1].x and p.z >= zone[0].z and p.z <= zone[1].z
