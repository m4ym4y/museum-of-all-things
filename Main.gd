extends Node

export (PackedScene) var room_scene

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# north = +x
# west = -z

const THICKNESS = 1
const OPPOSING_WALL_MAP = {
	"NorthWall": "SouthWall",
	"SouthWall": "NorthWall",
	"WestWall": "EastWall",
	"EastWall": "WestWall"
}

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var first_room = room_scene.instance()
	var second_room = room_scene.instance()

	first_room.init(10, 10, 4)
	second_room.init(20, 20, 4)
	attach_room(first_room, second_room, "NorthWall", 2, 1, 2)

	add_child(first_room)
	add_child(second_room)

func attach_room (room1, room2, room1_wall_name, door_left, door_width, door_height):
	room1.get_node(room1_wall_name).add_door(door_left, door_width, door_height)

	var room2_wall = room2.get_node(OPPOSING_WALL_MAP[room1_wall_name])
	room2_wall.add_door(room2_wall.wall_width / 2.0, door_width, door_height)

	if room1_wall_name == "NorthWall" or room1_wall_name == "SouthWall":
		room2.set_translation(Vector3(door_left - room1.room_width / 2.0, 0, -room2.room_length / 2.0 - room1.room_length / 2.0 - 2 * THICKNESS))
	else:
		room2.set_translation(Vector3(room2.room_width / 2.0, 0, door_left))

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("click"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
