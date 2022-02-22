extends Spatial

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
const PREVIEW_WIDTH = 2.0
const PREVIEW_HEIGHT = 4.0

func init(width, height):
	scale = Vector3(1.0, height / PREVIEW_HEIGHT, width / PREVIEW_WIDTH)

func interact():
	print("interact!")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
