extends Node
signal loaded_room

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

const ROOM_DIMENSION = {
	"NorthWall": "width",
	"SouthWall": "width",
	"WestWall": "length",
	"EastWall": "length"
}

var DOOR_LIST = {}
var ROOM_LIST = {}
var ROOM_MAP = {
	"Central Room": {
		width = 10,
		length = 10,
		height = 4,
		doors = {
			"Dinosaur": {
				wall = "NorthWall",
				left = 4,
				width = 1,
				height = 2
			},
			"North Room": {
				wall = "NorthWall",
				left = 2,
				width = 1,
				height = 2
			},
			"South Room": {
				wall = "SouthWall",
				left = 2,
				width = 1,
				height = 2
			},
			"West Room": {
				wall = "WestWall",
				left = 2,
				width = 1,
				height = 2
			},
			"East Room": {
				wall = "EastWall",
				left = 2,
				width = 1,
				height = 2
			}
		}
	},
	"North Room": {
		width = 20,
		length = 20,
		height = 4,
		doors = {
			"North-West Room": {
				wall = "WestWall",
				left = 5,
				width = 1,
				height = 2
			}
		}
	},
	"South Room": {
		width = 40,
		length = 16,
		height = 4,
		doors = {}
	},
	"West Room": {
		width = 20,
		length = 10,
		height = 4,
		doors = {}
	},
	"East Room": {
		width = 12,
		length = 10,
		height = 6,
		doors = {}
	},
	"North-West Room": {
		width = 10,
		length = 20,
		height = 6,
		doors = {}
	}
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

func load_room (room_name):
	if ROOM_MAP.has(room_name):
		emit_signal("loaded_room", room_name)
		return
	$HTTPRequest.request("http://localhost:8080/wikipedia/" + room_name)

func create_room_from_map (room_name):
	if ROOM_LIST.has(room_name):
		return ROOM_LIST[room_name]

	var room_spec = ROOM_MAP[room_name]
	var room = room_scene.instance()
	room.init(room_spec.width, room_spec.length, room_spec.height, room_name)

	for room2_name in room_spec.doors:
		var door_spec = room_spec.doors[room2_name]
		var door = room.get_node(door_spec.wall).add_door(
			door_spec.left, door_spec.width, door_spec.height, room2_name, true)
		init_door(door, room_name, room2_name)

	ROOM_LIST[room_name] = room
	return room

func init_door(door, room1_name, room2_name):
	DOOR_LIST[room1_name + '/' + room2_name] = door.get_node("DoorBody")
	door.get_node("DoorBody").connect("try_to_open", self, "_on_Door_try_to_open",
			[room1_name, room2_name])

func get_door(from_room, to_room):
	return DOOR_LIST[from_room + '/' + to_room]

func _on_Door_try_to_open (door_body, room1_name, room2_name):
	var room1 = ROOM_LIST[room1_name]
	var room1_spec = ROOM_MAP[room1_name]
	print('opening door from room', room1_name, 'to', room2_name)

	if not ROOM_MAP.has(room2_name):
		load_room(room2_name)
		yield(self, 'loaded_room')

	# unload all rooms other than the two active rooms
	# TODO: also close all doors
	for name in ROOM_LIST:
		if name != room1_name and name != room2_name:
			ROOM_LIST[name].queue_free()
			ROOM_LIST.erase(name)

	if not ROOM_LIST.has(room2_name):
		var door_spec = room1_spec.doors[room2_name]
		var room2_spec = ROOM_MAP[room2_name]

		room2_spec.doors[room1_name] = {
			width = door_spec.width,
			height = door_spec.height,
			left = room2_spec[ROOM_DIMENSION[door_spec.wall]] / 2.0,
			wall = OPPOSING_WALL_MAP[door_spec.wall]
		}

		var room2 = create_room_from_map(room2_name)
		var room2_offset = get_room_offset(door_spec, room1_spec, room2)
		room2.set_translation(room1.get_translation() + room2_offset)
		add_child(room2)

	print("door back is ", get_door(room2_name, room1_name))

	get_door(room2_name, room1_name).open()
	door_body.open()

func _on_request_completed(result, response_code, headers, body):
	print('got result', response_code, body.get_string_from_utf8())
	var room_spec = JSON.parse(body.get_string_from_utf8()).result
	ROOM_MAP[room_spec.name] = room_spec
	emit_signal("loaded_room", room_spec.name)

# Called when the node enters the scene tree for the first time.
func _ready():
	$HTTPRequest.connect("request_completed", self, "_on_request_completed")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# load_room("Dinosaur")
	# yield(self, 'loaded_room')
	var start_room = create_room_from_map("Central Room")
	add_child(start_room)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("click"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
