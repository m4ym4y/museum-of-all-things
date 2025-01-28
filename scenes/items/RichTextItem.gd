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

func _center_vertically(label):
  # Ensure the SubViewport is sized
  var viewport_size = $SubViewport.size
  
  # Get mipmapped image from viewport
  #get_tree().create_timer(0.05).timeout.connect(_set_texture)
  call_deferred("_set_texture")

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

func _set_texture():
  await get_tree().process_frame
  var viewport_image = $SubViewport.get_texture().get_image()
  viewport_image.generate_mipmaps()
  var viewport_texture = ImageTexture.create_from_image(viewport_image)
  $Sprite3D.texture = viewport_texture
  $SubViewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
