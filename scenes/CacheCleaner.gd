extends Node

@export var max_cache_size = 5e8
@export var target_cache_size = 5e8

func _exit_tree():
  if CacheControl.auto_limit_cache_enabled():
    Util.t_start()
    var settings = SettingsManager.get_settings("data")
    if settings.has("cache_limit_size"):
      CacheControl.cull_cache_to_size(
        settings.cache_limit_size,
        settings.cache_limit_size / 2
      )
    else:
      CacheControl.cull_cache_to_size(max_cache_size, target_cache_size)
    Util.t_end("cull_cache_to_size")
