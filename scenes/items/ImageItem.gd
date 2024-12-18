extends Sprite3D

signal loaded

var image_url
var _image
var width
var height
var text
var title
var plate_style

var plate_margin = 0.05
var max_text_height = 0.5

@onready var plate_black = preload("res://assets/textures/black.tres")
@onready var plate_white = preload("res://assets/textures/flat_white.tres")

@onready var text_white = Color(0.8, 0.8, 0.8)
@onready var text_black = Color(0.0, 0.0, 0.0)
@onready var text_clear = Color(0.0, 0.0, 0.0, 0.0)

func get_image_size():
  return Vector2(_image.get_width(), _image.get_height())

func _update_text_plate():
  var aabb = $Label.get_aabb()
  if aabb.size.length() == 0:
    return

  if aabb.size.y > max_text_height:
    $Label.font_size -= 1
    call_deferred("_update_text_plate")
    return

  if not plate_style:
    return

  var plate = $Label/Plate
  plate.visible = true
  plate.scale = Vector3(aabb.size.x + 2 * plate_margin, 1, aabb.size.y + 2 * plate_margin)
  plate.position.y = -(aabb.size.y / 2.0)

func _on_image_loaded(url, image, _ctx):
  if url != image_url:
    return

  DataManager.loaded_image.disconnect(_on_image_loaded)
  _image = image
  texture = _image

  var label = $Label
  label.text = Util.strip_markup(text)
  call_deferred("_update_text_plate")

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

    label.position.y = (-height / 2.0) - 0.2
    # label.translation.y = -width - 0.1
    label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    emit_signal("loaded")

func _on_image_complete(files, _ctx):
  if files.has(title):
    var data = ExhibitFetcher.get_result(title)
    if data:
      ExhibitFetcher.images_complete.disconnect(_on_image_complete)
      ExhibitFetcher.commons_images_complete.disconnect(_on_image_complete)
      _set_image(data)

func _set_image(data):
  # ensure this wasn't handled after free
  var label = $Label
  if is_instance_valid(label) and data.has("license_short_name") and data.has("artist"):
    text += "\n"
    text += data.license_short_name + " " + Util.strip_html(data.artist)
    label.text = text
    call_deferred("_update_text_plate")

  if data.has("src"):
    image_url = Util.normalize_url(data.src)
    DataManager.loaded_image.connect(_on_image_loaded)
    DataManager.request_image(data.src)

# Called when the node enters the scene tree for the first time.
func _ready():
  if not plate_style:
    pass
  elif plate_style == "white":
    $Label.modulate = text_black
    $Label.outline_modulate = text_clear
    $Label/Plate.material_override = plate_white
    $Label.font_size = 32
  elif plate_style == "black":
    $Label.modulate = text_white
    $Label.outline_modulate = text_black
    $Label/Plate.material_override = plate_black
    $Label.font_size = 32

func init(_title, _width, _height, _text, _plate_style = null):
  width = _width
  height = _height
  text = _text
  title = _title
  plate_style = _plate_style

  var data = ExhibitFetcher.get_result(title)
  if data:
    _set_image(data)
  else:
    ExhibitFetcher.images_complete.connect(_on_image_complete)
    ExhibitFetcher.commons_images_complete.connect(_on_image_complete)
