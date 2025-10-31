extends Node

# @todo Should we keep the cells in octants (for performance)?
var _cells := {}

func set_cell_item(pos: Vector3i, item: int, _orientation: int) -> void:
  if item == -1:
    _cells.erase(pos)
  else:
    _cells[pos] = item

func get_cell_item(pos: Vector3i) -> int:
  return _cells.get(pos, -1)

func update_from_gridmap(gridmap: GridMap) -> void:
  for pos in gridmap.get_used_cells():
    var item := gridmap.get_cell_item(pos)
    var orientation := gridmap.get_cell_item_orientation(pos)
    set_cell_item(pos, item, orientation)
