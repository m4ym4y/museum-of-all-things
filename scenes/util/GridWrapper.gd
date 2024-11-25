extends Node

@onready var _grid
@onready var _cells_set = []

func _notification(what):
  if what == NOTIFICATION_PREDELETE:
    _on_free()

func _on_free():
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
  return _grid.get_cell_item(pos)

func get_orthogonal_index_from_basis(basis):
  return _grid.get_orthogonal_index_from_basis(basis)
