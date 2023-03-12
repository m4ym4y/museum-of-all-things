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
	# in future this will be init with wikipedia article
	"""init(['hello', 'world', 'test', 'lorem', 'ipsum',
		'hello', 'world', 'test', 'lorem', 'ipsum',
		'hello', 'world', 'test', 'lorem', 'ipsum',
		'hello', 'world', 'test', 'lorem', 'ipsum',
		'hello', 'world', 'test', 'lorem', 'ipsum',
		'hello', 'world', 'test', 'lorem', 'ipsum'
	])"""
	init([
		{
			"type": "image",
			"src": "//upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Einstein_1921_by_F_Schmutzer_-_restoration.jpg/640px-Einstein_1921_by_F_Schmutzer_-_restoration.jpg",
			"text": "caption"
		},
		{
			"type": "text",
			"text": "Albert Einstein (/ˈaɪnstaɪn/ EYEN-styne;[6] German: [ˈalbɛʁt ˈʔaɪnʃtaɪn] (listen); 14 March 1879 – 18 April 1955) was a German-born theoretical physicist,[7] widely acknowledged to be one of the greatest and most influential physicists of all time. Einstein is best known for developing the theory of relativity, but he also made important contributions to the development of the theory of quantum mechanics. Relativity and quantum mechanics are the two pillars of modern physics.[3][8] His mass–energy equivalence formula E = mc2, which arises from relativity theory, has been dubbed 'the world's most famous equation'."
		},
		{
			"type": "image",
			"src": "//upload.wikimedia.org/wikipedia/commons/thumb/f/fb/Albert_Einstein_at_the_age_of_three_%281882%29.jpg/320px-Albert_Einstein_at_the_age_of_three_%281882%29.jpg",
			"text": "Einstein at the age of three in 1882"
		},
		{
			"type": "text",
			"text": "His work is also known for its influence on the philosophy of science.[10][11] He received the 1921 Nobel Prize in Physics 'for his services to theoretical physics, and especially for his discovery of the law of the photoelectric effect',[12] a pivotal step in the development of quantum theory. His intellectual achievements and originality resulted in 'Einstein' becoming synonymous with 'genius'.[13] Einsteinium, one of the synthetic elements in the periodic table, was named in his honor."
		},
		{
			"type": "image",
			"src": "//upload.wikimedia.org/wikipedia/commons/thumb/a/ad/Albert_Einstein_as_a_child.jpg/640px-Albert_Einstein_as_a_child.jpg",
			"text": "Einstein in 1893 (age 14)"
		},
		{
			"type": "image",
			"src": "//upload.wikimedia.org/wikipedia/commons/thumb/c/c3/Albert_Einstein%27s_exam_of_maturity_grades_%28color2%29.jpg/640px-Albert_Einstein%27s_exam_of_maturity_grades_%28color2%29.jpg",
			"text": "Einstein's Matura certificate, 1896[note 2]"
		},
		{
			"type": "image",
			"src": "//upload.wikimedia.org/wikipedia/commons/thumb/8/87/Albert_Einstein_and_his_wife_Mileva_Maric.jpg/640px-Albert_Einstein_and_his_wife_Mileva_Maric.jpg",
			"text": "Albert Einstein and Mileva Marić Einstein, 1912"
		},
		{
			"type": "image",
			"src": "//upload.wikimedia.org/wikipedia/commons/thumb/a/a0/Einstein_patentoffice.jpg/640px-Einstein_patentoffice.jpg",
			"text": "Einstein in 1904 (age 25)"
		},
		{
			"type": "image",
			"src": "//upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Einstein_thesis.png/640px-Einstein_thesis.png",
			"text": "Cover image of the PhD dissertation of Albert Einstein defended in 1905"
		},
	])

# TODO: put this in main class instead
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event.is_action_pressed("click"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func add_room():
	pass

func get_angle(child):
	if child.properties.has("angle"):
		return float(child.properties.angle) * 2.0 * PI / 360.0
	else:
		return 0.0

# start with items that are just text
func init(items):
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
