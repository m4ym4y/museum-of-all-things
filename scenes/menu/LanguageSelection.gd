extends OptionButton

const LANGUAGES = [
  "en",
  "pt",
  "fr",
]

func _on_language_item_selected(index: int) -> void:
  var language = LANGUAGES[index]
  TranslationServer.set_locale(language)
  ExhibitFetcher.set_language(language)
  GlobalMenuEvents.emit_set_language(language)
