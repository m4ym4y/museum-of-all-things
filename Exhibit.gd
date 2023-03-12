extends Spatial

const room_types = [
	preload("res://room_scenes/Hallway1.tscn"),
	preload("res://room_scenes/Hallway2.tscn")
]

const ImageItem = preload("res://room_items/ImageItem.tscn")
const TextItem = preload("res://room_items/TextItem.tscn")

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func add_room():
	pass

func get_angle(child):
	if child.properties.has("angle"):
		return float(child.properties.angle) * 2.0 * PI / 360.0
	else:
		return 0.0

# start with items that are just text
func init(data):
	var items = data.items
	var exit_pos = Vector3(0, 0, 0)

	while items.size() > 0:
		# todo: choose room randomly
		var room = room_types[1].instance()
		var entrance_pos = Vector3(0, 0, 0)
		var next_exit_pos

		# add as many items as can fit in the room
		for child in room.get_node("map").get_children():
			if child.name.ends_with("entrance"):
				entrance_pos = child.translation
				print("found entrance: ", entrance_pos)

			elif child.name.ends_with("exit"):
				next_exit_pos = child.translation
				print("found exit: ", next_exit_pos)

			elif child.name.ends_with("item"):
				print("found item")
				var item = items.pop_front()
				if not item:
					continue

				"""var item_scene = Label3D.new()
				item_scene.text = item
				print('angle:', get_angle(child))"""
				
				var item_scene
				if item.type == "image":
					item_scene = ImageItem.instance()
					item_scene.init(item.src, 1, 1, item.text)
				elif item.type == "text":
					item_scene = TextItem.instance()
					item_scene.init(item.text)

				item_scene.rotation.y = get_angle(child)
				child.add_child(item_scene)

		room.translation = exit_pos - entrance_pos
		add_child(room)
		exit_pos = room.translation + next_exit_pos

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
