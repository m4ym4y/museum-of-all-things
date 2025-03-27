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
  Util.resizeTextToPx($Text, $Text.width * max_lines)

func _ready():
  if starting_text:
    text = starting_text
  if not arrow:
    $Arrow.visible = false
  else:
    left = arrow_left
