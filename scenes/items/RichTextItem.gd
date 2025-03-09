extends Node3D

static var margin_top = 100

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass

func init(text):
  var label = $SubViewport/Control/RichTextLabel
  var t = Util.strip_markup(text)
  label.text = t
  call_deferred("_center_vertically", label)
  _replace_with_mipmapped_texture.call_deferred()

func _center_vertically(label):
  # Ensure the SubViewport is sized
  var viewport_size = $SubViewport.size

  # Get the content height from the RichTextLabel
  var content_height = label.get_content_height()

  if content_height > viewport_size.y - 2 * margin_top:
    var text_len = len(label.text)
    var new_len = text_len * (float(content_height - 2 * margin_top) / float(content_height))
    label.text = Util.trim_to_length_sentence(label.text, min(text_len - 1, new_len))
    call_deferred("_center_vertically", label)
    return

  # Calculate the centered Y position
  var y_position = max((viewport_size.y - content_height) / 2, margin_top)

  # Set the position of the RichTextLabel
  label.position.y = y_position

static var num_images_pending = 0
func _replace_with_mipmapped_texture():
  num_images_pending += 1
  for _i in range(num_images_pending): # Hacky way to wait at least 1 frame, and only have one image processed per frame
    await RenderingServer.frame_post_draw
  var img: Image = $SubViewport.get_texture().get_image() # Synchronous readpixels 🤢, wait for 4.4 and use https://github.com/godotengine/godot/pull/100110
  img.convert(Image.FORMAT_LA8); # Assume grayscale, use less vram
  img.generate_mipmaps()
  $Sprite3D.texture = ImageTexture.create_from_image(img)
  $SubViewport.queue_free() # Remove the viewport to free its render target
  num_images_pending -= 1
