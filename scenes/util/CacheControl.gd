extends Node

signal cache_size_result(cache_info)

var cache_dir = "user://cache/"
var _cache_stat_thread = Thread.new()
var CACHE_STAT_QUEUE = "CacheStat"
var _cache_size_info = { "count": 0, "size": 0 }
var _last_stat_time = 0
var _max_stat_age = 2000

func _ready():
  _cache_stat_thread.start(_cache_stat_loop)

func _exit_tree():
  WorkQueue.set_quitting()
  _cache_stat_thread.wait_to_finish()

func _cache_stat_loop():
  while not WorkQueue.get_quitting():
    var item = WorkQueue.process_queue(CACHE_STAT_QUEUE)
    if item and len(item) > 0 and item[0] == "size":
      if Time.get_ticks_msec() - _last_stat_time < _max_stat_age:
        call_deferred("_emit_cache_size")
      else:
        _cache_size_info = _get_cache_size()
        _last_stat_time = Time.get_ticks_msec()
        call_deferred("_emit_cache_size")

func _emit_cache_size():
  emit_signal("cache_size_result", _cache_size_info)

func auto_limit_cache_enabled():
  var settings = SettingsManager.get_settings("data")
  if settings:
    return settings.auto_limit_cache
  else:
    return true

func clear_cache():
  var dir = DirAccess.open(cache_dir)
  dir.list_dir_begin()

  while true:
    var file = dir.get_next()
    if not file:
      break
    dir.remove(file)

func calculate_cache_size():
  WorkQueue.add_item(CACHE_STAT_QUEUE, ["size"])

func _get_cache_size():
  var dir = DirAccess.open(cache_dir)
  dir.list_dir_begin()

  var file = dir.get_next()
  var total_length = 0
  var count = 0
  while file:
    count += 1
    var handle = FileAccess.open(cache_dir + file, FileAccess.READ)
    if handle:
      total_length += handle.get_length()
      handle.close()
    file = dir.get_next()

  return {
    "count": count,
    "size": total_length
  }

func cull_cache_to_size(max_size: int, target_size: int):
  var dir = DirAccess.open(cache_dir)
  dir.list_dir_begin()

  var file = dir.get_next()
  var file_array = []
  var total_length = 0
  while file:
    var file_path = cache_dir + file
    var handle = FileAccess.open(file_path, FileAccess.READ)
    if handle:
      var file_len = handle.get_length()
      total_length += file_len
      handle.close()
      file_array.append([
        file,
        file_len,
        FileAccess.get_modified_time(file_path),
      ])
    file = dir.get_next()

  var deletion_target = total_length - target_size
  if total_length > max_size and deletion_target > 0:
    file_array.sort_custom(func(a, b): return a[2] < b[2])
    for file_entry in file_array:
      dir.remove(file_entry[0])
      deletion_target -= file_entry[1]
      if deletion_target <= 0:
        break
