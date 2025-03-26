@tool
extends MeshInstance3D

@export var no_light: bool = false
@export var title_color: Color = Color.WHITE
@export var hide_titles: bool = false
@export var title_text = "Art"
@export var subtitle_text = "Featured Art Exhibits"

var max_title_length_px = 320

func _resize_title():
  var t = $Title
  while t.font.get_string_size(t.text, t.horizontal_alignment, -1, t.font_size).x > max_title_length_px:
    t.font_size -= 1

func _ready() -> void:
  if no_light:
    $MeshInstance3D.visible = false
    $SpotLight3D.visible = false

  if hide_titles:
    $Title.visible = false
    $Subtitle.visible = false
  else:
    $Title.modulate = title_color
    $Title.text = title_text
    $Subtitle.modulate = title_color
    $Subtitle.text = subtitle_text
    _resize_title()
