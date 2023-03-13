extends Spatial

signal open_door(to_exhibit, door_translation, door_angle)

var entrance = Vector3(0, 0, 0)
var entrance_angle = 0

const room_types = [
	preload("res://room_scenes/Hallway1.tscn"),
	preload("res://room_scenes/Hallway2.tscn")
]

const ImageItem = preload("res://room_items/ImageItem.tscn")
const TextItem = preload("res://room_items/TextItem.tscn")

const DoorPlaceholder = preload("res://DoorPlaceholder.tscn")
const Door = preload("res://Door.tscn")

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
	var doors = data.doors
	var exit_pos = Vector3(0, 0, 0)

	while items.size() > 0:
		# todo: choose room randomly
		var room = room_types[1].instance()
		var entrance_pos = Vector3(0, 0, 0)
		var next_exit_pos

		# add as many items as can fit in the room
		for child in room.get_node("map").get_children():
			if child.name.ends_with("entrance"):
				# set the overall exhibit entrance if this is the first room
				if not entrance:
					entrance = child.translation
					entrance_angle = get_angle(child)

				entrance_pos = child.translation
				print("found entrance: ", entrance_pos)

			elif child.name.ends_with("exit"):
				next_exit_pos = child.translation
				print("found exit: ", next_exit_pos)

			elif child.name.ends_with("door"):
				print("found door")
				var door_to = doors.pop_front()

				var door_scene
				if door_to:
					door_scene = Door.instance()
					door_scene.init(door_to)
					door_scene.connect("open", self, "_on_door_open", [door_to, child])
				else:
					# block off the door if we have no link
					door_scene = DoorPlaceholder.instance()

				door_scene.rotation.y = get_angle(child)
				child.add_child(door_scene)

			elif child.name.ends_with("item"):
				print("found item")
				var item = items.pop_front()
				if not item:
					continue
				
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

func _on_door_open(door_to, door_object):
	emit_signal("open_door", door_to, door_object.global_transform.origin, get_angle(door_object))

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
