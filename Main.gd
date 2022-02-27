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

var ROOM_LIST = {}
var ROOM_MAP = {
	name = "Central Room",
	width = 10,
	length = 10,
	height = 4,
	doors = [
		{
			wall = "NorthWall",
			left = 2,
			width = 1,
			height = 2,
			room = {
				name = "North Room",
				width = 20,
				length = 20,
				height = 4,
				doors = [
					{
						wall = "WestWall",
						left = 5,
						width = 1,
						height = 2,
						room = {
							name = "North-West Room",
							width = 10,
							length = 20,
							height = 6,
							doors = []
						}
					}
				]
			}
		},
		{
			wall = "SouthWall",
			left = 2,
			width = 1,
			height = 2,
			room = {
				name = "South Room",
				width = 40,
				length = 16,
				height = 4,
				doors = []
			}
		},
		{
			wall = "WestWall",
			left = 2,
			width = 1,
			height = 2,
			room = {
				name = "West Room",
				width = 20,
				length = 10,
				height = 4,
				doors = []
			}
		},
		{
			wall = "EastWall",
			left = 2,
			width = 1,
			height = 2,
			room = {
				name = "East Room",
				width = 12,
				length = 10,
				height = 6,
				doors = []
			}
		}
	]
}

func get_room_offset (door_spec, room1_spec, room2):
	var room_left_offset_width = door_spec.left - room1_spec.width / 2.0
	var room_left_offset_length = door_spec.left - room1_spec.length / 2.0
	var room_offset_length = room2.room_length / 2.0 + room1_spec.length / 2.0 + 2 * THICKNESS
	var room_offset_width = room2.room_width / 2.0 + room1_spec.width / 2.0 + 2 * THICKNESS

	if door_spec.wall == "NorthWall":
		return Vector3(room_left_offset_width, 0, -room_offset_length)
	elif door_spec.wall == "SouthWall":
		return Vector3(-room_left_offset_width, 0, room_offset_length)
	elif door_spec.wall == "WestWall":
		return Vector3(-room_offset_width, 0, -room_left_offset_length)
	else: # EastWall
		return Vector3(room_offset_width, 0, room_left_offset_length)

func create_room_from_map (room_spec):
	if ROOM_LIST.has(room_spec.name):
		return ROOM_LIST[room_spec.name]

	var room = room_scene.instance()
	room.init(room_spec.width, room_spec.length, room_spec.height, room_spec.name)

	for door_spec in room_spec.doors:
		var door = room.get_node(door_spec.wall).add_door(
			door_spec.left, door_spec.width, door_spec.height, door_spec.room.name, true)

		door.get_node("DoorBody").connect("try_to_open", self, "_on_Door_try_to_open",
			[room_spec, door_spec, room])

	ROOM_LIST[room_spec.name] = room
	return room

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var start_room = create_room_from_map(ROOM_MAP)
	add_child(start_room)

func _on_Door_try_to_open (door_body, room1_spec, door_spec, room1):
	print('open door handler')

	var room2 = create_room_from_map(door_spec.room)
	var room2_wall = room2.get_node(OPPOSING_WALL_MAP[door_spec.wall])
	var room2_offset = get_room_offset(door_spec, room1_spec, room2)
	var door = room2_wall.add_door(room2_wall.wall_width / 2.0,
			door_spec.width, door_spec.height, room1_spec.name, false)

	room2.set_translation(room1.get_translation() + room2_offset)
	add_child(room2)
	door_body.open()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("click"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
