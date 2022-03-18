extends Sprite3D

var image_url
var PNG_REGEX = RegEx.new()
var JPG_REGEX = RegEx.new()
var width
var height

const PIXELS_PER_METER = 100

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
func _on_request_completed(result, response_code, headers, body):
	print("LOADED IMAGE ", image_url, " ", response_code)
	var image_texture = ImageTexture.new()
	var image = Image.new()

	if JPG_REGEX.search(image_url.to_lower()):
		image.load_jpg_from_buffer(body)
	elif PNG_REGEX.search(image_url.to_lower()):
		image.load_png_from_buffer(body)

	image.resize(width * PIXELS_PER_METER, height * PIXELS_PER_METER,
			Image.INTERPOLATE_NEAREST)

	image_texture.create_from_image(image)
	texture = image_texture

# Called when the node enters the scene tree for the first time.
func _ready():
	PNG_REGEX.compile("\\.png$")
	JPG_REGEX.compile("\\.(jpg|jpeg)$")
	if image_url:
		$HTTPRequest.request(image_url)
	pass

func init(url, _width, _height):
	print("LOADING IMAGE BY URL ", url)
	image_url = url
	width = _width
	height = _height
	$HTTPRequest.connect("request_completed", self, "_on_request_completed")
	if is_inside_tree():
		$HTTPRequest.request(image_url)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
