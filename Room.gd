extends Spatial

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

const THICKNESS = 1
var room_width
var room_length
var room_height
var room_name

# Called when the node enters the scene tree for the first time.
func init(width, length, height, name = "Untitled Room"):
	room_width = width
	room_length = length
	room_height = height
	room_name = name
	
	$Floor.init(width, length)

	$WestWall.init(length, height)
	$WestWall.set_translation(Vector3(-width / 2, 0, 0))

	$NorthWall.init(width, height)
	$NorthWall.set_translation(Vector3(0, 0, -length / 2 - THICKNESS))

	$SouthWall.init(width, height)
	$SouthWall.set_translation(Vector3(0, 0, length / 2 + THICKNESS))

	$EastWall.init(length, height)
	$EastWall.set_translation(Vector3(width / 2, 0, 0))

	$Ceiling.init(width, length)
	$Ceiling.set_translation(Vector3(0, height, 0))

	$OmniLight.set_translation(Vector3(0, height / 2, 0))
	$OmniLight.omni_range = max(width, length)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
