extends Sprite3D

var image_url
var PNG_REGEX = RegEx.new()
var JPG_REGEX = RegEx.new()
var width
var height
var text

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
func _on_request_completed(result, _response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("Failed to fetch the image at " + image_url)
		return

	var image_texture = ImageTexture.new()
	var image = Image.new()

	if JPG_REGEX.search(image_url.to_lower()):
		image.load_jpg_from_buffer(body)
	elif PNG_REGEX.search(image_url.to_lower()):
		image.load_png_from_buffer(body)

	image_texture.create_from_image(image)
	texture = image_texture

	var label = $Label
	label.text = text

	if image.get_width() != 0:
		pixel_size = float(width) / float(image.get_width())
		# var to_image_bottom = width * (float(image.get_width) / float(image.get_height))
		label.position.y = -width * (float(image.get_height() / 2) / float(image.get_width())) - 0.1
		# label.translation.y = -width - 0.1
		label.vertical_alignment = VALIGN_TOP
		if label.position.y < -float(height) / 2.0:
			position.y -= label.position.y + float(height) / 2.0
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
