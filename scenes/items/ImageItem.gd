extends Sprite3D

signal loaded

var image_url
var _image
var width
var height
var text

func get_image_size():
	return Vector2(_image.get_width(), _image.get_height())

func _on_image_loaded(url, image, _ctx):
	if url != image_url:
		return

	DataManager.loaded_image.disconnect(_on_image_loaded)
	_image = image
	texture = _image

	var label = $Label
	label.text = text

	if _image.get_width() != 0:
		pixel_size = min(
			float(width) / float(_image.get_width()),
			float(height) / float(_image.get_height())
		)
		# var to_image_bottom = width * (float(image.get_width) / float(image.get_height))
		label.position.y = -min(width, height) * (float(_image.get_height() / 2) / float(_image.get_width())) - 0.1
		# label.translation.y = -width - 0.1
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		emit_signal("loaded")
	else:
		label.text += "\n(image could not be displayed)"

# Called when the node enters the scene tree for the first time.
func _ready():
	if image_url:
		$HTTPRequest.request(image_url)
	pass

func init(url, _width, _height, _text):
	if not url:
		return
	image_url = Util.normalize_url(url)
	width = _width
	height = _height
	text = _text

	DataManager.loaded_image.connect(_on_image_loaded)
	DataManager.request_image(image_url)
