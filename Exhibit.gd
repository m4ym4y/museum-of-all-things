extends Spatial

const room_types = [
	preload("res://room_scenes/Hallway1.tscn")
]

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
	# in future this will be init with wikipedia article
	init(['hello', 'world', 'test', 'lorem', 'ipsum'])

# TODO: put this in main class instead
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("click"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func add_room():
	pass

# start with items that are just text
func init(items):
	var exit_pos = Vector3(0, 0, 0)

	while items.size() > 0:
		# todo: choose room randomly
		var room = room_types[0].instance()
		var entrance_pos = Vector3(0, 0, 0)
		var next_exit_pos

		# add as many items as can fit in the room
		for child in room.get_children():
			if child.name.ends_with("entrance"):
				entrance_pos = child.translation
				print("found entrance: ", entrance_pos)

			elif child.name.ends_with("exit"):
				next_exit_pos = child.translation
				print("found exit: ", next_exit_pos)

			elif child.name.ends_with("item"):
				print("found item")
				var item = items.pop_front()

				var item_scene = Label3D.new()
				item_scene.text = item
				item_scene.rotation.y = float(child.properties.angle) * 2.0 * PI / 360.0
				print('angle:', float(child.properties.angle) * 2.0 * PI / 360.0)

				child.add_child(item_scene)

		room.translation = exit_pos - entrance_pos
		add_child(room)
		exit_pos = room.translation + next_exit_pos

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
