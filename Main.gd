extends Node

export (PackedScene) var room_scene

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# north = +x
# west = -z

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var first_room = room_scene.instance()
	var second_room = room_scene.instance()

	first_room.init(10, 10, 6)
	first_room.get_node("NorthWall").add_door(4, 3, 4)
	add_child(first_room)

	second_room.init(20, 20, 6)
	second_room.get_node("SouthWall").add_door(9, 3, 4)
	second_room.set_translation(Vector3(0, 0, -17))
	add_child(second_room)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("click"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
