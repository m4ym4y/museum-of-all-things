extends Sprite3D

signal loaded

var image_url
var PNG_REGEX = RegEx.new()
var JPG_REGEX = RegEx.new()
var _image
var width
var height
var text

func get_image_size():
	return Vector2(_image.get_width(), _image.get_height())

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
func _on_request_completed(result, _response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Failed to fetch the image at " + image_url)
		return

	_image = Image.new()
	var error

	if JPG_REGEX.search(image_url.to_lower()):
		error = _image.load_jpg_from_buffer(body)
		if error != OK:
			return
	elif PNG_REGEX.search(image_url.to_lower()):
		error = _image.load_png_from_buffer(body)
		if error != OK:
			return

	if error != OK:
		push_error('error loading image ', image_url, ' code ', _response_code)
	else:
		texture = ImageTexture.create_from_image(_image)

	var label = $Label
	label.text = text

	if _image.get_width() != 0:
		pixel_size = min(
			float(width) / float(_image.get_width()),
			float(height) / float(_image.get_height())
		)
		# var to_image_bottom = width * (float(image.get_width) / float(image.get_height))
		label.position.y = -width * (float(_image.get_height() / 2) / float(_image.get_width())) - 0.1
		# label.translation.y = -width - 0.1
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		if label.position.y < -float(height) / 2.0:
			position.y -= label.position.y + float(height) / 2.0
		emit_signal("loaded")
	else:
		label.text += "\n(image could not be displayed)"

# Called when the node enters the scene tree for the first time.
func _ready():
	PNG_REGEX.compile("\\.png$")
	JPG_REGEX.compile("\\.(jpg|jpeg)$")
	if image_url:
		$HTTPRequest.request(image_url)
	pass

func init(url, _width, _height, _text):
	if not url:
		return
	if url.begins_with('//'):
		image_url = 'https:' + url
	else:
		image_url = url
	width = _width
	height = _height
	text = _text
	$HTTPRequest.connect("request_completed", Callable(self, "_on_request_completed"))
	if is_inside_tree():
		$HTTPRequest.request(image_url)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
