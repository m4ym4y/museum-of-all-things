extends Node3D

var L_ARROW = "←"
var R_ARROW = "→"

var text: String:
	get:
		return $Text.text
	set(v):
		$Text.text = v

var left: bool:
	get:
		return $Arrow.text == L_ARROW
	set(v):
		$Arrow.text = L_ARROW if v else R_ARROW
