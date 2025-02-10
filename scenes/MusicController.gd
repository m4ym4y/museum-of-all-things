extends Node3D

@onready var tracks = [
  preload("res://assets/sound/Music/Music - 1.ogg"),
  preload("res://assets/sound/Music/Music - 2.ogg"),
  preload("res://assets/sound/Music/Music - 3.ogg"),
  preload("res://assets/sound/Music/Music - 4.ogg"),
]

@export var min_space_start: float = 20.0
@export var min_space: float = 60.0 * 3
@export var max_space: float = 60.0 * 6
var last_track = null

func _ready() -> void:
  var wait_time = randf_range(min_space_start, max_space)
  if OS.is_debug_build():
    print("waiting for first track. time=", wait_time)
  get_tree().create_timer(wait_time).timeout.connect(_play_track)
  $AudioStreamPlayer.finished.connect(_reset_timer)

func _play_track():
  var track_idx
  if last_track == null:
    track_idx = randi() % len(tracks)
  else: 
   track_idx = (last_track + (randi() % (len(tracks) - 1))) % len(tracks)
  last_track = track_idx

  if OS.is_debug_build():
    print("playing music. track #", track_idx)

  $AudioStreamPlayer.stream = tracks[track_idx]
  $AudioStreamPlayer.seek(0.0)
  $AudioStreamPlayer.play()

func _reset_timer():
  var wait_time = randf_range(min_space, max_space)
  if OS.is_debug_build():
    print("waiting for next track. time=", wait_time)
  get_tree().create_timer(wait_time).timeout.connect(_play_track)
