extends Node3D

#static var max_chars = 2500
static var max_chars = 1500
static var margin_top = 100

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass

func init(text):
  var label = $SubViewport/Control/RichTextLabel
  var t = Util.trim_to_length_sentence(Util.strip_markup(text), max_chars)
  label.text = t
  call_deferred("_center_vertically", label)

func _center_vertically(label):
  # Ensure the SubViewport is sized
  var viewport_size = $SubViewport.size

  # Get the content height from the RichTextLabel
  var content_height = label.get_content_height()

  # Calculate the centered Y position
  var y_position = max((viewport_size.y - content_height) / 2, margin_top)

  # Set the position of the RichTextLabel
  label.position.y = y_position
