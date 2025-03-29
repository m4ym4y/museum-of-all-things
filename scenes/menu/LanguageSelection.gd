extends OptionButton

const LANGUAGES = [
  "en",
  "pt",
  "fr",
]

func _ready():
  var locale = LanguageManager.get_locale()
  var idx = LANGUAGES.find(locale)
  if idx >= 0:
    select(idx)
  item_selected.connect(_on_language_item_selected)

func _on_language_item_selected(index: int) -> void:
  var locale = LANGUAGES[index]
  LanguageManager.set_locale(locale)
