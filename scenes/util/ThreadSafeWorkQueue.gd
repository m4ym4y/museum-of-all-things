extends Node

var QUEUE_WAIT_TIMEOUT_MS = 50
var _global_queue_lock = Mutex.new()
var _current_exhibit_lock = Mutex.new()
var _current_exhibit = "$Lobby"
var _queue_map = {}

func set_current_exhibit(title):
	_current_exhibit_lock.lock()
	_current_exhibit = title
	_current_exhibit_lock.unlock()

func get_current_exhibit():
	_current_exhibit_lock.lock()
	var res = _current_exhibit
	_current_exhibit_lock.unlock()
	return res

func _get_queue(name):
	var res
	_global_queue_lock.lock()
	if not _queue_map.has(name):
		_queue_map[name] = {
			"exhibit_queues": {},
			"lock": Mutex.new()
		}
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
		queue.exhibit_queues[exhibit].append(item)
	else:
		queue.exhibit_queues[exhibit].push_front(item)
	queue.lock.unlock()

func process_queue(name):
	var queue = _get_queue(name)

	while true:
		var exhibit = get_current_exhibit()
		queue.lock.lock()
		var item
		if queue.exhibit_queues.has(exhibit):
			item = queue.exhibit_queues[exhibit].pop_front()
		queue.lock.unlock()
		if item:
			return item
		OS.delay_msec(QUEUE_WAIT_TIMEOUT_MS)
