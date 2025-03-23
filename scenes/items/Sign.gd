extends Node3D

@export var starting_text: String = ""
@export var arrow: bool = true
@export var arrow_left: bool = true

static var max_lines = 4
var L_ARROW = "←"
var R_ARROW = "→"
var _text_value = ""

var text: String:
  get:
    return _text_value
  set(v):
    _text_value = v
    $Text.text = v.replace("$", "")
    call_deferred("_resize_text")

var left: bool:
  get:
    return $Arrow.text == L_ARROW
  set(v):
    $Arrow.text = L_ARROW if v else R_ARROW

func _resize_text():
  var t = $Text
  while t.font.get_string_size(t.text, t.horizontal_alignment, -1, t.font_size).x > t.width * max_lines:
    t.font_size -= 1

func _ambient_light_energy_change(ambient_light_energy: float):
  var emissive_material = $MeshInstance3D.get_active_material(1)
  emissive_material.emission_enabled = true if ambient_light_energy == 0 else false
  $MeshInstance3D.set_surface_override_material(1, emissive_material)

func _ready():
  GraphicsManager.ambient_light_energy_change.connect(_ambient_light_energy_change)
  if starting_text:
    text = starting_text
  if not arrow:
    $Arrow.visible = false
  else:
    left = arrow_left
