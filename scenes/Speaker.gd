extends Node

var _voice

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  var voices = DisplayServer.tts_get_voices_for_language("en")
  if len(voices) == 0:
    return
  _voice = voices[0]

func speak(text):
  if _voice:
    DisplayServer.tts_speak(text, _voice)

func stop():
  DisplayServer.tts_stop()
