extends Node3D

@onready var _footsteps = {
  "hard": $FootstepsHard,
  "soft": $FootstepsSoft
}

var _default_floor_type = "hard"
var _floor_material_map = {
  11: "soft", # carpet
}

var _grid
func init(grid):
  _grid = grid

func play_footsteps(on_floor, velocity, max_speed):
  if not _grid:
    return

  var flat_velocity = Vector2(velocity.x, velocity.z).length()

  if on_floor and flat_velocity > 0:
    var floor_cell = Util.worldToGrid(global_position) - Vector3.UP
    var floor_cell_type = _grid.get_cell_item(floor_cell)
    var step_type = _floor_material_map.get(
      floor_cell_type,
      _default_floor_type
    )

    for step in _footsteps.keys():
      if step == step_type:
        _footsteps[step].pitch_scale = flat_velocity / max_speed
        if not _footsteps[step].playing:
          _footsteps[step].play()
      else:
        _footsteps[step].stop()
  else:
    for step in _footsteps.keys():
      _footsteps[step].stop()
