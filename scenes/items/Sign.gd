extends Node3D

@export var starting_text: String = ""
@export var arrow: bool = true
@export var arrow_left: bool = true

var L_ARROW = "←"
var R_ARROW = "→"

var text: String:
	get:
		return $Text.text
	set(v):
		$Text.text = v.replace("$", "")

var left: bool:
	get:
		return $Arrow.text == L_ARROW
	set(v):
		$Arrow.text = L_ARROW if v else R_ARROW

func _ready():
	if starting_text:
		text = starting_text
	if not arrow:
		$Arrow.visible = false
	else:
		left = arrow_left
