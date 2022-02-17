extends StaticBody

const PREVIEW_WIDTH = 10.0
const PREVIEW_LENGTH = 10.0

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(width, length):
	scale = Vector3(width / PREVIEW_WIDTH, 1, length / PREVIEW_LENGTH)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
