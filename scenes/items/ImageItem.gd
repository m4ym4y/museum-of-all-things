extends Sprite3D

signal loaded

var image_url
var _image
var width
var height
var text
var title

func get_image_size():
	return Vector2(_image.get_width(), _image.get_height())

func _on_image_loaded(url, image, _ctx):
	if url != image_url:
		return

	DataManager.loaded_image.disconnect(_on_image_loaded)
	_image = image
	texture = _image

	var label = $Label
	label.text = Util.strip_markup(text)

	var w = _image.get_width()
	var h = _image.get_height()
	var fw = float(w)
	var fh = float(h)

	if w != 0:
		pixel_size = min(
			float(width) / fw,
			float(height) / fh
		)

		var height = 2.0 if h > w else 2.0 * (fh / fw)
		# var to_image_bottom = width * (float(image.get_width) / float(image.get_height))

		label.position.y = (-height / 2.0) - 0.1
		# label.translation.y = -width - 0.1
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		emit_signal("loaded")

func _on_image_complete(files, _ctx):
	if files.has(title):
		var data = ExhibitFetcher.get_result(title)
		if data:
			_set_image(data)

func _set_image(data):
	# ensure this wasn't handled after free
	var label = $Label
	if is_instance_valid(label) and data.has("license_short_name") and data.has("artist"):
		text += "\n"
		text += data.license_short_name + " " + Util.strip_html(data.artist)
		label.text = text

	if data.has("src"):
		image_url = Util.normalize_url(data.src)
		DataManager.loaded_image.connect(_on_image_loaded)
		DataManager.request_image(data.src)

# Called when the node enters the scene tree for the first time.
func _ready():
	if image_url:
		$HTTPRequest.request(image_url)
	pass

func init(_title, _width, _height, _text):
	width = _width
	height = _height
	text = _text
	title = _title

	var data = ExhibitFetcher.get_result(title)
	if data:
		_set_image(data)
	else:
		ExhibitFetcher.images_complete.connect(_on_image_complete)
