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

	var start_room = room_scene.instance()
	var north_room = room_scene.instance()
	var south_room = room_scene.instance()
	var west_room = room_scene.instance()
	var east_room = room_scene.instance()
	var north_west_room = room_scene.instance()

	start_room.init(10, 10, 4, "Central Room")
	north_room.init(20, 20, 4, "North Room")
	south_room.init(40, 16, 4, "South Room")
	west_room.init(20, 10, 4, "West Room")
	east_room.init(12, 10, 6, "East Room")
	north_west_room.init(10, 20, 6, "North-West Room")

	attach_room(start_room, north_room, "NorthWall", 2, 1, 2)
	attach_room(start_room, south_room, "SouthWall", 2, 1, 2)
	attach_room(start_room, west_room, "WestWall", 5, 1, 2)
	attach_room(start_room, east_room, "EastWall", 5, 1, 2)
	attach_room(north_room, north_west_room, "WestWall", 5, 1, 2)

	add_child(start_room)
	#add_child(north_room)
	#add_child(south_room)
	#add_child(west_room)
	#add_child(east_room)
	#add_child(north_west_room)

func _on_Door_try_to_open (doorBody, room1, room2, room1_wall_name, door_left, door_width, door_height):
	print('open door handler')

	var room2_wall = room2.get_node(OPPOSING_WALL_MAP[room1_wall_name])
	room2_wall.add_door(room2_wall.wall_width / 2.0, door_width, door_height, room1.room_name, false)

	var room2_offset
	if room1_wall_name == "NorthWall":
		room2_offset = Vector3(
			door_left - room1.room_width / 2.0,
			0,
			-room2.room_length / 2.0 - room1.room_length / 2.0 - 2 * THICKNESS
		)
	elif room1_wall_name == "SouthWall":
		room2_offset = Vector3(
			door_left - room1.room_width / 2.0,
			0,
			room2.room_length / 2.0 + room1.room_length / 2.0 + 2 * THICKNESS
		)
	elif room1_wall_name == "WestWall":
		room2_offset = Vector3(
			-room2.room_width / 2.0 - room1.room_width / 2.0 - 2 * THICKNESS,
			0,
			door_left - room1.room_length / 2.0
		)
	else: # EastWall
		room2_offset = Vector3(
			room2.room_width / 2.0 + room1.room_width / 2.0 + 2 * THICKNESS,
			0,
			door_left - room1.room_length / 2.0
		)

	room2.set_translation(room1.get_translation() + room2_offset)
	add_child(room2)
	doorBody.open()

func attach_room (room1, room2, room1_wall_name, door_left, door_width, door_height):
	var door = room1.get_node(room1_wall_name).add_door(door_left, door_width, door_height, room2.room_name, true)

	door.get_node("DoorBody").connect("try_to_open", self, "_on_Door_try_to_open",
		[room1, room2, room1_wall_name, door_left, door_width, door_height])

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("click"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
