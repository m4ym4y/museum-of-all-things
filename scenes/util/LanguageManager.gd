extends Node

const _settings_ns = "language"
var _locale = "en"

func _create_settings_obj():
  return {
    "locale": _locale
  }

func _ready():
  var loaded_settings = SettingsManager.get_settings(_settings_ns)
  if loaded_settings:
    set_locale(loaded_settings.locale)

func get_locale():
  return _locale

func set_locale(locale: String):
  _locale = locale
  TranslationServer.set_locale(locale)
  ExhibitFetcher.set_language(locale)
  GlobalMenuEvents.emit_set_language(locale)
  SettingsManager.save_settings(_settings_ns, _create_settings_obj())
