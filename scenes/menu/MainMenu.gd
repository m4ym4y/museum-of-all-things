extends Control

signal start
signal settings

var fade_in_start = Color(0.0, 0.0, 0.0, 1.0)
var fade_in_end = Color(0.0, 0.0, 0.0, 0.0)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  _on_visibility_changed()
  call_deferred("_start_fade_in")

func _on_visibility_changed():
  if visible:
    $MarginContainer/VBoxContainer/Start.grab_focus()

func _start_fade_in():
  $FadeIn.color = fade_in_start
  $FadeInStage2.color = fade_in_start
  var tween = get_tree().create_tween()
  tween.tween_property($FadeIn, "color", fade_in_end, 1.5)
  tween.tween_property($FadeInStage2, "color", fade_in_end, 1.5)
  tween.set_trans(Tween.TRANS_LINEAR)
  tween.set_ease(Tween.EASE_IN_OUT)

func _on_start_pressed():
  emit_signal("start")

func _on_settings_pressed():
  emit_signal("settings")

func _on_quit_button_pressed():
  get_tree().quit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass

func _on_language_item_selected(index: int) -> void:
  if index == 0:
    TranslationServer.set_locale("en")
  if index == 1:
    TranslationServer.set_locale("pt")
  # if index == 2:
  #   TranslationServer.set_locale("fr")

  var lang = TranslationServer.get_locale()

  ExhibitFetcher.WIKIPEDIA_PREFIX = "https://" + lang + ".wikipedia.org/wiki/"

  ExhibitFetcher.search_endpoint = "https://" + lang + ".wikipedia.org/w/api.php?action=query&format=json&list=search&srprop=title&srsearch="
  ExhibitFetcher.random_endpoint = "https://" + lang + ".wikipedia.org/w/api.php?action=query&format=json&generator=random&grnnamespace=0&prop=info"

  ExhibitFetcher.wikitext_endpoint = "https://" + lang + ".wikipedia.org/w/api.php?action=query&prop=revisions|extracts|pageprops&ppprop=wikibase_item&explaintext=true&rvprop=content&format=json&redirects=1&titles="
  ExhibitFetcher.images_endpoint = "https://" + lang + ".wikipedia.org/w/api.php?action=query&prop=imageinfo&iiprop=extmetadata|url&iiurlwidth=640&iiextmetadatafilter=LicenseShortName|Artist&format=json&redirects=1&titles="
  ExhibitFetcher.wikidata_endpoint = "https://www.wikidata.org/w/api.php?action=wbgetclaims&uselang=" + lang + "&format=json&entity="

  ExhibitFetcher.wikimedia_commons_category_images_endpoint = "https://commons.wikimedia.org/w/api.php?action=query&uselang=" + lang + "&generator=categorymembers&gcmtype=file&gcmlimit=max&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=640&iiextmetadatafilter=Artist|LicenseShortName&format=json&gcmtitle="
  ExhibitFetcher.wikimedia_commons_gallery_images_endpoint = "https://commons.wikimedia.org/w/api.php?action=query&uselang=" + lang + "&generator=images&gimlimit=max&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=640&iiextmetadatafilter=Artist|LicenseShortName&format=json&titles="
