extends Node3D

var _current_player
var _fade_duration = 2.5
var _ambience_tracks = [
  preload("res://assets/sound/Global Ambience/Global ambience 1.ogg"),
  preload("res://assets/sound/Global Ambience/Global ambience 2.ogg"),
  preload("res://assets/sound/Global Ambience/Global ambience 3.ogg"),
  preload("res://assets/sound/Global Ambience/Global ambience 4.ogg"),
]

func _random_track():
  return _ambience_tracks[randi() % len(_ambience_tracks)]

func _create_player(res):
  var audio = AudioStreamPlayer.new()
  audio.stream = res
  audio.volume_db = -80.0
  audio.autoplay = true
  audio.bus = &"Ambience"
  audio.play()
  add_child(audio)
  return audio

func _fade_between(audio1, res2, duration):
  var audio2 = _create_player(res2)
  var tween = get_tree().create_tween()
  tween.tween_property(audio2, "volume_db", 0, duration)
  tween.tween_property(audio1, "volume_db", -80, duration)
  tween.finished.connect(_fade_finished.bind(audio1))
  return audio2

func _fade_finished(audio1):
  audio1.queue_free()

func _next_track():
  _current_player = _fade_between(_current_player, _random_track(), _fade_duration)

func _ready():
  call_deferred("_start_playing")

func _start_playing():
  _current_player = _create_player(_random_track())
  _current_player.volume_db = 0.0
  $Timer.timeout.connect(_next_track)
  $Timer.start()
