extends OptionButton

var _languages

func _get_lang_array():
  var arr = ["en"]
  for locale in TranslationServer.get_loaded_locales():
    if locale != "en":
      arr.append(locale)
  return arr

func _ready():
  _languages = _get_lang_array()
  for i in range(1, len(_languages)):
    add_item(TranslationServer.get_language_name(_languages[i]))

  var locale = LanguageManager.get_locale()
  var idx = _languages.find(locale)
  if idx >= 0:
    select(idx)
  item_selected.connect(_on_language_item_selected)

func _on_language_item_selected(index: int) -> void:
  var locale = _languages[index]
  LanguageManager.set_locale(locale)
