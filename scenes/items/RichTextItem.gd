extends Node3D

static var margin_top = 100

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass

func init(text):
  var label = $SubViewport/Control/RichTextLabel
  var t = Util.strip_markup(text)
  t = Util.replace_unclosed_bbcodes(t)
  label.text = t
  call_deferred("_center_vertically", label)
  MipmapThread.get_viewport_texture_with_mipmaps.call_deferred($SubViewport, func(texture):
    $Sprite3D.texture = texture
    $SubViewport.queue_free()
  )

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
