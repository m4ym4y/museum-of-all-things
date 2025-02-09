extends Node

const _settings_file: String = "user://user_settings.json"
var _settings: Dictionary = {}

func _read_settings():
  var file = FileAccess.open(_settings_file, FileAccess.READ)
  if not file:
    return null
  var json_text = file.get_as_text()
  file.close()
  _settings = JSON.parse_string(json_text)

func _write_settings():
  var json_text = JSON.stringify(_settings)
  var file = FileAccess.open(_settings_file, FileAccess.WRITE)
  file.store_string(json_text)
  file.close()

func get_settings(ns: String):
  if not _settings:
    _read_settings()
  return _settings.get(ns, null)

func save_settings(ns: String, obj: Dictionary):
  _settings[ns] = obj
  _write_settings()
