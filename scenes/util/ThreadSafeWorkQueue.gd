extends Node

var QUEUE_WAIT_TIMEOUT_MS = 50
var DEFAULT_FRAME_PACING = 9
var _global_queue_lock = Mutex.new()
var _current_exhibit_lock = Mutex.new()
var _current_exhibit = "$Lobby"
var _quitting = false
var _queue_map = {}

func _exit_tree():
  set_quitting()

func set_quitting():
  _quitting = true

func get_quitting():
  return _quitting

func set_current_exhibit(title):
  _current_exhibit_lock.lock()
  _current_exhibit = title
  _current_exhibit_lock.unlock()

func get_current_exhibit():
  _current_exhibit_lock.lock()
  var res = _current_exhibit
  _current_exhibit_lock.unlock()
  return res

func setup_queue(name, frame_pacing=DEFAULT_FRAME_PACING):
  _queue_map[name] = {
    "exhibit_queues": {},
    "lock": Mutex.new(),
    "last_frame_with_item": 0,
    "frame_pacing": frame_pacing,
  }

func _get_queue(name):
  var res
  _global_queue_lock.lock()
  if not _queue_map.has(name):
    setup_queue(name)
  res = _queue_map[name]
  _global_queue_lock.unlock()
  return res

func add_item(name, item, _exhibit=null, front=false):
  var exhibit = _exhibit if _exhibit else get_current_exhibit()
  var queue = _get_queue(name)

  queue.lock.lock()
  if not queue.exhibit_queues.has(exhibit):
    queue.exhibit_queues[exhibit] = []

  if front:
    queue.exhibit_queues[exhibit].push_front(item)
  else:
    queue.exhibit_queues[exhibit].append(item)
  queue.lock.unlock()

func process_queue(name):
  var queue = _get_queue(name)

  if Util.is_using_threads():
    while not _quitting:
      var item = _process_queue_item(queue)
      if item:
        return item
      Util.delay_msec(QUEUE_WAIT_TIMEOUT_MS)
  else:
    # Pace the items out across several frames
    var cur_frame = Engine.get_frames_drawn()
    if cur_frame - queue["frame_pacing"] >= queue["last_frame_with_item"]:
      var item = _process_queue_item(queue)
      if item:
        queue["last_frame_with_item"] = cur_frame
        return item
    return null

func _process_queue_item(queue):
  if _quitting:
    return null

  var exhibit = get_current_exhibit()
  queue.lock.lock()
  var item
  if queue.exhibit_queues.has(exhibit):
    item = queue.exhibit_queues[exhibit].pop_front()
  queue.lock.unlock()
  return item
