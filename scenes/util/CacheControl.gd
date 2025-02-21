extends Node
class_name CacheControl

static var cache_dir = "user://cache/"

static func auto_limit_cache_enabled():
  var settings = SettingsManager.get_settings("data")
  if settings:
    return settings.auto_limit_cache
  else:
    return true

static func clear_cache():
  var dir = DirAccess.open(cache_dir)
  dir.list_dir_begin()

  while true:
    var file = dir.get_next()
    if not file:
      break
    dir.remove(file)

static func get_cache_size():
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

static func cull_cache_to_size(max_size: int, target_size: int):
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
