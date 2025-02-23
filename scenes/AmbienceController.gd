extends Node3D

var _current_player
var _fade_duration = 2.5
var _ambience_tracks = [
  preload("res://assets/sound/Global Ambience/Global ambience 1.ogg"),
  preload("res://assets/sound/Global Ambience/Global ambience 2.ogg"),
  preload("res://assets/sound/Global Ambience/Global ambience 3.ogg"),
  preload("res://assets/sound/Global Ambience/Global ambience 4.ogg"),
]

var _ambient_voice_space_min = 60
var _ambient_voice_space_max = 300
var _ambient_voices = [
  preload("res://assets/sound/Voices/Voices 1.ogg"),
  preload("res://assets/sound/Voices/Voices 2.ogg"),
  preload("res://assets/sound/Voices/Voices 3.ogg"),
  preload("res://assets/sound/Voices/Voices 4.ogg"),
  preload("res://assets/sound/Voices/Voices 5.ogg"),
  preload("res://assets/sound/Voices/Voices 6.ogg"),
  preload("res://assets/sound/Voices/Voices 7.ogg"),
  preload("res://assets/sound/Voices/Voices 8.ogg"),
  preload("res://assets/sound/Voices/Voices 9.ogg"),
]

var _ambience_event_space_min = 30
var _ambience_event_space_max = 180
var _ambience_events_weighted = [
  [2,  preload("res://assets/sound/Easter Eggs/Bird Cry 1.ogg")],
  [2,  preload("res://assets/sound/Easter Eggs/Bird Flapping 1.ogg")],
  [2,  preload("res://assets/sound/Easter Eggs/Peepers 1.ogg")],
  [5,  preload("res://assets/sound/Easter Eggs/Cricket Loop.ogg")],
  [5,  preload("res://assets/sound/Easter Eggs/Easter Eggs pen drop 1.ogg")],
  [10, preload("res://assets/sound/Easter Eggs/Random Ambience 1.ogg")],
  [10, preload("res://assets/sound/Easter Eggs/Random Ambience 2.ogg")],
  [10, preload("res://assets/sound/Easter Eggs/Random Ambience 3.ogg")],
  [10, preload("res://assets/sound/Easter Eggs/Random Ambience 4.ogg")],
]

func _ambience_voice_timer():
  print("ambience voice timer")
  get_tree().create_timer(randi_range(_ambient_voice_space_min, _ambient_voice_space_max)).timeout.connect(_play_ambience_voice)

func _ambience_event_timer():
  get_tree().create_timer(randi_range(_ambience_event_space_min, _ambience_event_space_max)).timeout.connect(_play_ambience_event)

func _play_ambience_voice():
  print("playing ambience voice")
  var player = _create_player(_ambient_voices[randi() % len(_ambient_voices)], 0.0)
  player.finished.connect(_clean_player.bind(player))
  player.finished.connect(_ambience_voice_timer)

func _play_ambience_event():
  _ambience_event_timer()
  var weight_sum = 0
  for ev in _ambience_events_weighted:
    weight_sum += ev[0]
  var choice = randi_range(1, weight_sum)
  for ev in _ambience_events_weighted:
    choice -= ev[0]
    if choice <= 0:
      var player = _create_player(ev[1], 0.0)
      player.finished.connect(_clean_player.bind(player))
      break

func _random_track():
  return _ambience_tracks[randi() % len(_ambience_tracks)]

func _create_player(res, volume):
  var audio = AudioStreamPlayer.new()
  audio.stream = res
  audio.volume_db = volume
  audio.autoplay = true
  audio.bus = &"Ambience"
  add_child(audio)
  audio.play()
  return audio

func _fade_between(audio1, res2, duration):
  var audio2 = _create_player(res2, -80.0)
  var tween = get_tree().create_tween()
  tween.tween_property(audio2, "volume_db", 0, duration)
  tween.tween_property(audio1, "volume_db", -80, duration)
  tween.finished.connect(_clean_player.bind(audio1))
  return audio2

func _clean_player(audio1):
  audio1.queue_free()

func _next_track():
  _current_player = _fade_between(_current_player, _random_track(), _fade_duration)

func _ready():
  call_deferred("_start_playing")

func _start_playing():
  _current_player = _create_player(_random_track(), 0.0)
  $Timer.timeout.connect(_next_track)
  $Timer.start()
  _ambience_event_timer()
  _ambience_voice_timer()
