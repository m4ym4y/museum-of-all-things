extends Node

signal loaded_image(url: String, image: Image)

@onready var COMMON_HEADERS = [ "accept: image/png, image/jpeg; charset=utf-8" ]
@onready var _in_flight = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _get_hash(input: String) -> String:
	var context = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(input.to_utf8_buffer())
	var hash_result = context.finish()
	#print("hashing. from=%s to=%s" % [input, hash_result.hex_encode()])
	return hash_result.hex_encode()

func _detect_image_type(data: PackedByteArray) -> String:
	if data.size() < 8:
		return "Unknown"  # Insufficient data to determine type

	# Convert to hexadecimal strings for easy comparison
	var header = data.slice(0, 8)
	var hex_header = ""
	for byte in header:
		hex_header += ("%02x" % byte).to_lower()

	# Check PNG signature
	if hex_header.begins_with("89504e470d0a1a0a"):
		return "PNG"

	# Check JPEG signature
	if hex_header.begins_with("ffd8ff"):
		return "JPEG"

	# Check WebP signature (RIFF and WEBP)
	if hex_header.begins_with("52494646"):  # "RIFF"
		if data.size() >= 12:
			var riff_type = data.slice(8, 12).get_string_from_ascii()
			if riff_type == "WEBP":
				return "WebP"

	# Check SVG (look for '<?xml' or '<svg')
	if data.size() >= 5:
		var xml_start = data.slice(0, 5).get_string_from_utf8()
		if xml_start.begins_with("<?xml") or xml_start.begins_with("<svg"):
			return "SVG"
	return "Unknown"

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

func _create_and_emit_image(url, data, ctx):
	var fmt = _detect_image_type(data)
	var image = Image.new()
	if fmt == "PNG":
		image.load_png_from_buffer(data)
	elif fmt == "JPEG":
		image.load_jpg_from_buffer(data)
	elif fmt == "SVG":
		image.load_svg_from_buffer(data)
	elif fmt == "WebP":
		image.load_webp_from_buffer(data)
	else:
		return null

	if image.get_width() == 0:
		return null

	var texture = ImageTexture.create_from_image(image)
	_emit_image(url, texture, ctx)

func _emit_image(url, texture, ctx):
	if texture == null:
		return
	call_deferred("emit_signal", "loaded_image", url, texture, ctx)

func request_image(url, ctx=null):
	var data = _read_url(url)
	if data:
		_create_and_emit_image(url, data, ctx)
		return

	if _in_flight.has(url):
		return

	_in_flight[url] = true
	var request = HTTPRequest.new()
	request.request_completed.connect(_on_image_request_complete.bind(url, request, ctx))
	add_child(request)
	if OS.is_debug_build():
		print("fetching image ", url)
	var error = request.request(url, COMMON_HEADERS)
	if error != OK:
		_in_flight.erase(url)

func _on_image_request_complete(result, code, _headers, body, url, request, ctx):
	_in_flight.erase(url)
	request.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("failed to fetch image ", code, " ", url)
		return

	_create_and_emit_image(url, body, ctx)
	_write_url(url, body)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
