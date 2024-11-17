extends Node3D

const Exhibit = preload("res://Exhibit.tscn")
const starting_exhibit = "Starting_Page"
const static_exhibit_data = {
	"Starting_Page": {
		"force_room_index": 1,
		"items": [
			{
				"type": "text",
				"text": "Welcome to the wikipedia museum! Here you can explore Wikipedia in a virtual space. To step between exhibits, walk up to one of the doors at the edge of the room and hit 'E'. Be careful not to fall into the void!!!"
			}
		],
		"doors": [ "Dinosaur", "Albert_Einstein", "Fungus", "Soup", "Butterfly", "2022_in_science" ]
	}
}

var loaded_exhibits = {}

func load_exhibit(title, position = Vector3(0, 0, 0), angle = 0, from = ""):
	var exhibit = Exhibit.instantiate()

	exhibit.init(static_exhibit_data[title], from)
	loaded_exhibits[title] = exhibit

	exhibit.connect("open_door", Callable(self, "_on_open_door").bind(title))
	exhibit.rotation.y = angle
	# exhibit.global_transform.origin = translation # - exhibit.entrance
	exhibit.position = position # - exhibit.entrance

	# TODO: position exhibit at the correct location according to the triggered door
	add_child(exhibit)

var loading_exhibit
var loading_door_translation
var loading_door_angle
var loading_exhibit_from

func _on_open_door(to_exhibit, door_translation, door_angle, from_exhibit):
	# Free exhibits other than the one we're in
	for k in loaded_exhibits.keys():
		if k != from_exhibit:
			loaded_exhibits[k].queue_free()
			loaded_exhibits.erase(k)
	
	if static_exhibit_data.has(to_exhibit):
		load_exhibit(to_exhibit, door_translation, door_angle, from_exhibit)
		return

	loading_exhibit = to_exhibit
	loading_door_translation = door_translation
	loading_door_angle = door_angle + loaded_exhibits[from_exhibit].rotation.y
	loading_exhibit_from = from_exhibit
	$ExhibitFetcher.fetch(to_exhibit)

	#load_exhibit(to_exhibit, door_translation, door_angle)

func _on_fetch_complete(exhibit_data):
	static_exhibit_data[loading_exhibit] = exhibit_data
	load_exhibit(loading_exhibit, loading_door_translation, loading_door_angle, loading_exhibit_from)

func _ready():
	randomize()
	$ExhibitFetcher.connect("fetch_complete", Callable(self, "_on_fetch_complete"))
	load_exhibit(starting_exhibit)
