extends Spatial

signal open_door(to_exhibit, door_translation, door_angle)

var entrance = Vector3(0, 0, 0)
var entrance_angle = 0
var entrance_ref
var from_exhibit = ""

const room_types = [
	{
		"scene": preload("res://room_scenes/Hallway2.tscn"),
		"orientation": 0
	},
	{
		"scene": preload("res://room_scenes/HallwayRing.tscn"),
		"orientation": 1
	},
	{
		"scene": preload("res://room_scenes/HallwayBalcony1.tscn"),
		"orientation": 1
	},
	{
		"scene": preload("res://room_scenes/HallwayT.tscn"),
		"orientation": -1
	}
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

func rotate_room(room, pivot, angle):
	var rotator = room.get_node("rotator")
	var map = room.get_node("rotator/map_and_lights")

	map.translation = -pivot
	rotator.rotation.y = angle
	rotator.translation = pivot

# TODO: refactor this method to break out the different cases
# start with items that are just text
func init(data, from = ""):
	from_exhibit = from

	var items = data.items
	var secondary_items = data.secondary_items if data.has("secondary_items") else []
	var doors = data.doors
	var exit_pos = Vector3(0, 0, 0)
	var exit_angle = 0

	if items.size() == 0 and secondary_items.size() > 0:
		items.push_back(secondary_items.pop_front())

	# TODO: we might need to start with a different orientation
	var orientation = 0

	while items.size() > 0:
		var room_index
		if data.has("force_room_index"):
			room_index = data.force_room_index
		else:
			room_index = randi() % room_types.size()
			while abs(orientation + room_types[room_index].orientation) >= 2:
				room_index = randi() % room_types.size()

		orientation += room_types[room_index].orientation
		var room = room_types[room_index].scene.instance()
		var entrance_pos = Vector3(0, 0, 0)
		var next_exit_pos
		var next_exit_angle
		var exit_ref

		# add as many items as can fit in the room
		for child in room.get_node("rotator/map_and_lights/map").get_children():
			if child.name.ends_with("entrance"):
				# set the overall exhibit entrance if this is the first room
				if not entrance:
					entrance = child.translation
					entrance_angle = get_angle(child)
					entrance_ref = child
					if from == "":
						_block_doorway(entrance_ref)
				entrance_pos = child.translation

			elif child.name.ends_with("exit"):
				next_exit_pos = child.translation
				next_exit_angle = get_angle(child)
				exit_ref = child

			elif child.name.ends_with("door"):
				var door_to = doors.pop_front()

				if door_to:
					_connect_doorway(child, door_to, room)
				else:
					_block_doorway(child)

			elif child.name.ends_with("item"):
				var item
				if items.size() > 0:
					item = items.pop_front()
				elif secondary_items.size() > 0:
					item = secondary_items.pop_front()
				else:
					continue

				var item_scene
				if item.type == "image":
					item_scene = ImageItem.instance()
					item_scene.init(item.src, 1.5, 1.5, item.text)
				elif item.type == "text":
					item_scene = TextItem.instance()
					item_scene.init(item.text)

				item_scene.rotation.y = get_angle(child)
				child.add_child(item_scene)

		# block exit if no more rooms
		if items.size() == 0:
			_block_doorway(exit_ref)

		room.translation = exit_pos - entrance_pos
		rotate_room(room, entrance_pos, exit_angle)
		add_child(room)
		exit_pos = room.translation + (next_exit_pos - entrance_pos).rotated(Vector3(0, 1, 0), room.get_node("rotator").rotation.y) + entrance_pos
		exit_angle = room.get_node("rotator").rotation.y + next_exit_angle

func _block_doorway(doorway_ref):
	var block = DoorPlaceholder.instance()
	block.rotation.y = get_angle(doorway_ref)
	doorway_ref.add_child(block)

func _connect_doorway(doorway_ref, door_to, room):
	var door = Door.instance()
	door.init(door_to)
	door.connect("open", self, "_on_door_open", [door_to, doorway_ref, room])
	door.rotation.y = get_angle(doorway_ref)
	doorway_ref.add_child(door)

func _on_door_open(door_to, door_object, room):
	emit_signal("open_door", door_to, door_object.global_transform.origin,
			get_angle(door_object) + room.get_node("rotator").rotation.y)

	# TODO: turn the entrance into a door to the previous exhibit instead?
	if entrance_ref and from_exhibit != "":
		_block_doorway(entrance_ref)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
