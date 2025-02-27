extends Node3D

# TODO: this should be a custom resource instead
@onready var _footsteps = {
  "hard": [
    #preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 1 reverb.ogg"),
    #preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 2 reverb.ogg"),
    #preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 3 reverb.ogg"),
    #preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 4 reverb.ogg"),
    #preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 5 reverb.ogg"),
    #preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 6 reverb.ogg"),
    #preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 7 reverb.ogg"),
    preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 8 reverb.ogg"),
    preload("res://assets/sound/Footsteps/Tile/Reverb/Footsteps Tile 9 reverb.ogg"),
  ],
  "soft": [
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 1.ogg"),
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 2.ogg"),
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 3.ogg"),
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 4.ogg"),
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 5.ogg"),
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 6.ogg"),
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 7.ogg"),
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 8.ogg"),
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 9.ogg"),
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 10.ogg"),
    preload("res://assets/sound/Footsteps/Carpet/Footsteps Carpet 11.ogg"),
  ],
  "water": [
    preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 1.ogg"),
    preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 2.ogg"),
    preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 3.ogg"),
    preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 4.ogg"),
    preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 5.ogg"),
    preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 6.ogg"),
    preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 7.ogg"),
    preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 8.ogg"),
    preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 9.ogg"),
    preload("res://assets/sound/Footsteps/Water/Water Footsteps Heavy 10.ogg"),
  ],
  "dirt": [
    preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 1.ogg"),
    preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 2.ogg"),
    preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 3.ogg"),
    preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 4.ogg"),
    preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 5.ogg"),
    preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 6.ogg"),
    preload("res://assets/sound/Footsteps/Dirt/Dirt Footsteps 7.ogg"),
  ],
  "leaves": [
    preload("res://assets/sound/Environmental Ambience/Leaves 1.ogg"),
    preload("res://assets/sound/Environmental Ambience/Leaves 2.ogg"),
    preload("res://assets/sound/Environmental Ambience/Leaves 3.ogg"),
  ],
}

@onready var audio_stream_player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var water_enter_sound = preload("res://assets/sound/Footsteps/Water/Player Enters Water 2.ogg")

var _default_floor_type = "hard"
var _floor_material_map = {
  11: "soft", # carpet
}

@export var _step_length: float = 3.0

var _on_floor = false
var _distance_from_last_step = 0.0
var _step_idx = 0
var _last_in_water = false
var _last_on_floor = false
@onready var _last_position = global_position

func _ready() -> void:
  audio_stream_player_3d.play()

func set_on_floor(on_floor):
  _on_floor = on_floor

func _physics_process(delta):
  var step = (global_position - _last_position).length()
  _last_position = global_position

  if not _on_floor:
    if _last_on_floor and _distance_from_last_step > _step_length / 2.0:
      call_deferred("_play_footstep")
    _last_in_water = false
    _distance_from_last_step = 0.0
    _last_on_floor = _on_floor
    return

  if _on_floor and not _last_on_floor:
    _last_on_floor = _on_floor
    _distance_from_last_step = 0.0
    call_deferred("_play_footstep")
    return

  _last_on_floor = _on_floor
  _distance_from_last_step += step

  # we've stopped, so play a step
  if _distance_from_last_step > _step_length / 2.0 and step == 0:
    _distance_from_last_step = 0.0
    call_deferred("_play_footstep")
  # otherwise play a step if our distance from last step exceeds step len
  elif _distance_from_last_step > _step_length:
    _distance_from_last_step = 0.0
    call_deferred("_play_footstep")

func _play_footstep(override_type=null):
  var grid = GlobalGridAccess.get_grid()
  if not grid:
    return

  var step_type
  var obj = $FloorCast.get_collider()
  if override_type:
    step_type = override_type
  elif obj and obj.is_in_group("footstep_dirt"):
    step_type = "dirt"
  elif obj and obj.is_in_group("footstep_water"):
    step_type = "water"
  else:
    var floor_cell = Util.worldToGrid(global_position) - Vector3.UP
    var floor_cell_type = grid.get_cell_item(floor_cell)
    step_type = _floor_material_map.get(
      floor_cell_type,
      _default_floor_type
    )


  var step_sfx_list = _footsteps[step_type]
  var step_sfx
  if step_type == "water" and not _last_in_water:
    step_sfx = water_enter_sound
  else:
    step_sfx = step_sfx_list[randi() % len(step_sfx_list)]

  var playback: AudioStreamPlaybackPolyphonic = audio_stream_player_3d.get_stream_playback()
  playback.play_stream(step_sfx)

  _last_in_water = step_type == "water"
