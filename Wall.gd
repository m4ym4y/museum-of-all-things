extends CSGCombiner


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
const PREVIEW_WIDTH = 10.0
const PREVIEW_HEIGHT = 10.0
const THICKNESS = 1.0

var wall_width
var wall_height

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(width, height):
	wall_width = width
	wall_height = height
	$CSGBox.set_scale(Vector3(1, height / PREVIEW_HEIGHT, width / PREVIEW_WIDTH))
	$CSGBox.set_translation(Vector3(-0.5, height / 2, 0))

func add_door(left, width, height):
	var doorway = CSGBox.new()
	doorway.set_depth(min(wall_width, width))
	doorway.set_width(THICKNESS)
	doorway.set_height(min(wall_height, height))
	doorway.set_translation(
			Vector3(-THICKNESS / 2, height / 2, -wall_width / 2 + left))
	doorway.set_operation(CSGShape.OPERATION_SUBTRACTION)
	add_child(doorway)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
