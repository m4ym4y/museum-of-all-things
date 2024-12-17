extends Node

var QUEUE_WAIT_TIMEOUT_MS = 50
var global_queue_lock = Mutex.new()
var queue_map = {}

func _get_queue(name):
	var res
	global_queue_lock.lock()
	if not queue_map.has(name):
		queue_map[name] = {
			"items": [],
			"lock": Mutex.new()
		}
	res = queue_map[name]
	global_queue_lock.unlock()
	return res

func add_item(name, item, front=false):
	var queue = _get_queue(name)
	queue.lock.lock()
	if front:
		queue.items.append(item)
	else:
		queue.items.push_front(item)
	queue.lock.unlock()

func process_queue(name):
	var queue = _get_queue(name)

	while true:
		queue.lock.lock()
		var item = queue.items.pop_front()
		queue.lock.unlock()
		if item:
			return item
		OS.delay_msec(QUEUE_WAIT_TIMEOUT_MS)
