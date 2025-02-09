extends Control

signal resume

func _on_back_pressed():
  emit_signal("resume")

func _on_visibility_changed():
  if visible:
    _refresh_cache_label()

func _refresh_cache_label():
  var result = CacheControl.get_cache_size()
  $CacheOptions/CacheLabel.text = "Cache (%s items, %3.2f GB)" % [result.count, result.size / 1000000000.0]

func _on_clear_cache_pressed():
  CacheControl.clear_cache()
  _refresh_cache_label()
