extends Node
class_name ItemProcessor

static var ignore_sections = [
	"references",
	"see also",
	"notes",
	"further reading",
	"external links",
	"bibliography",
	"gallery",
]

static var IMAGE_REGEX = RegEx.new()
static var s2_re = RegEx.new()

static var max_len_soft = 1000
static var  text_item_fmt = "[color=black][b][font_size=200]%s[/font_size][/b]\n\n%s"
static var section_fmt = "[p][b][font_size=100]%s[/font_size][/b][/p]\n\n"
static var p_fmt = "[p]%s[/p]\n\n"

static func _static_init():
	IMAGE_REGEX.compile("\\.(png|jpg|jpeg|webp|svg)$")
	s2_re.compile("^==[^=]")

static func _seeded_shuffle(seed, arr):
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(seed)
	Util.shuffle(rng, arr)

static func _add_text_item(items, title, text):
	if (
		not ignore_sections.has(title.to_lower().strip_edges()) and
		len(text) > 20
	):
		items.append({
			"type": "rich_text",
			"material": "marble",
			"text": text_item_fmt % [title, text]
		})

static func _clean_section(s):
	return s.replace("=", "").strip_edges()

static func _create_text_items(title, extract):
	var items = []
	var lines = extract.split("\n")

	var current_title = title
	var current_text = ""

	for line in lines:
		if line == "":
			continue
		elif s2_re.search(line):
			_add_text_item(items, current_title, current_text)
			current_title = _clean_section(line)
			current_text = ""
		elif len(current_text) < max_len_soft:
			if line.begins_with("="):
				current_text += section_fmt % _clean_section(line)
			else:
				current_text += p_fmt % line

	_add_text_item(items, current_title, current_text)

	return items

static func create_items(title, result):
	var items = []
	var doors = []

	if result:
		if result.has("extract"):
			items.append_array(_create_text_items(title, result.extract))

		if result.has("links"):
			doors = result.links.duplicate()
			_seeded_shuffle(title, doors)

		if result.has("images"):
			for image in result.images:
				if IMAGE_REGEX.search(image.src):
					items.append({
						"type": "image",
						"title": image.title if image.has("title") else "",
						"src": image.src,
						"text": Util.coalesce(image.text, image.src.split("/")[-1].uri_decode()),
					})

	var front_item = items.pop_front()
	_seeded_shuffle(title + ":items", items)
	items.push_front(front_item)

	return {
		"doors": doors,
		"items": items,
	}
