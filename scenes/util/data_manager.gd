extends Node

signal loaded_image(url: String, image: Image)

@onready var COMMON_HEADERS = [ "accept: application/json; charset=utf-8" ]
@onready var _in_flight = {}
@onready var _img_cache = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _get_hash(input: String) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(input.to_utf8_buffer())
	var hash_result = context.finish()
	return hash_result.hex_encode()

func _detect_image_type(buffer: PackedByteArray):
	if buffer.size() < 8:
		return null
	elif buffer.slice(0, 9) == PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]):
		return "PNG"
	elif buffer[0] == 0xFF and buffer[1] == 0xD8:
		return "JPEG"
	return null

func _write_url(url: String, data: PackedByteArray) -> void:
	#TODO: acquire lock?
	var filename = _get_hash(url)
	var f = FileAccess.open("user://" + filename, FileAccess.WRITE)
	if f:
		f.store_buffer(data)
		f.close()
	else:
		push_error("failed to write file ", url)

func _read_url(url: String):
	var filename = _get_hash(url)
	var f = FileAccess.open("user://" + filename, FileAccess.READ)
	if f:
		var data = f.get_buffer(f.get_length())
		f.close()
		return data
	else:
		return null

func load_json_data(url: String):
	var data = _read_url(url)
	if data:
		var json = data.get_string_from_utf8()
		return JSON.parse_string(json)
	else:
		return null

func save_json_data(url: String, json: Dictionary):
	var data = JSON.stringify(json).to_utf8_buffer()
	_write_url(url, data)

func _create_and_emit_image(url, data):
	var fmt = _detect_image_type(data)
	var image = Image.new()
	if fmt == "PNG":
		image.load_png_from_buffer(data)
	elif fmt == "JPEG":
		image.load_jpg_from_buffer(data)
	else:
		# TODO: we don't want to keep them waiting
		return null
	_img_cache[url] = data
	call_deferred("emit_signal", "loaded_image", url, image)

func request_image(url):
	if _img_cache.has(url):
		_create_and_emit_image(url, _img_cache[url])
		return

	var data = _read_url(url)
	if data:
		_create_and_emit_image(url, data)
		return

	if _in_flight.has(url):
		return

	_in_flight[url] = true
	var request = HTTPRequest.new()
	request.request_completed.connect(_on_image_request_complete.bind(url, request))
	add_child(request)
	if OS.is_debug_build():
		print("fetching image ", url)
	print
	var error = request.request(url, COMMON_HEADERS)
	if error != OK:
		_in_flight.erase(url)

func _on_image_request_complete(result, code, _headers, body, url, request):
	_in_flight.erase(url)
	request.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("failed to fetch image ", code, " ", url)
		return

	_create_and_emit_image(url, body)
	_write_url(url, body)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
