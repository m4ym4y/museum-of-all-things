extends MeshInstance3D

var max_length_title = 160
var max_search_length = 100

func _ready() -> void:
	Util.resizeTextToPx($Search, max_search_length)
	for child in get_children():
		if child is Label3D:
			Util.resizeTextToPx(child, max_length_title)
