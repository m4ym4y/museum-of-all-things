extends Spatial

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
export (PackedScene) var label3d_scene
export (PackedScene) var door_scene

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
	$CSGCombiner/CSGBox.set_scale(
		Vector3(1, height / PREVIEW_HEIGHT, width / PREVIEW_WIDTH))
	$CSGCombiner/CSGBox.set_translation(Vector3(-0.5, height / 2, 0))

func add_door(left, width, height, name = "Untitled Room", filled = false):
	var doorway = CSGBox.new()

	# TODO: less janky hack?
	var front_label = label3d_scene.instance()
	var back_label = label3d_scene.instance()

	front_label.set_label(name)
	back_label.set_label(name)
	back_label.flip_h = true

	front_label.set_translation(
		Vector3(0.01, height + 0.2, wall_width / 2 - left))
	back_label.set_translation(
		Vector3(-THICKNESS - 0.01, height + 0.2, wall_width / 2 - left))

	doorway.set_depth(min(wall_width, width))
	doorway.set_width(THICKNESS)
	doorway.set_height(min(wall_height, height))
	doorway.set_translation(
		Vector3(-THICKNESS / 2, height / 2, wall_width / 2 - left))
	doorway.set_operation(CSGShape.OPERATION_SUBTRACTION)

	var door
	if filled:
		door = door_scene.instance()
		door.init(width, height)
		door.set_translation(
			Vector3(-THICKNESS + door.THICKNESS / 2, height / 2, wall_width / 2 - left))
		add_child(door)

	add_child(front_label)
	add_child(back_label)
	$CSGCombiner.add_child(doorway)

	return door

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
