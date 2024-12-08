extends Node
class_name ItemProcessor

static var ignore_sections = [
	"references",
	"see also",
	"notes",
	"further reading",
	"external links",
	"external link s",
	"bibliography",
	"gallery",
	"sources",
]

static var IMAGE_REGEX = RegEx.new()
static var s2_re = RegEx.new()
static var template_re = RegEx.new()
static var links_re = RegEx.new()
static var extlinks_re = RegEx.new()
static var em_re = RegEx.new()
static var tag_re = RegEx.new()
static var whitespace_re = RegEx.new()
static var nl_re = RegEx.new()
static var alt_re = RegEx.new()
static var tokenizer = RegEx.new()
static var image_name_re = RegEx.new()
static var image_field_re = RegEx.new()

static var max_len_soft = 1000
static var text_item_fmt = "[color=black][b][font_size=50]%s[/font_size][/b]\n\n%s"
static var section_fmt = "[p][b][font_size=25]%s[/font_size][/b][/p]\n\n"
static var p_fmt = "[p]%s[/p]\n\n"

static func _static_init():
	IMAGE_REGEX.compile("\\.(png|jpg|jpeg|webp|svg)$")
	s2_re.compile("^==[^=]")
	template_re.compile("\\{\\{.*?\\}\\}")
	links_re.compile("\\[\\[([^|\\]]*?\\|)?(.*?)\\]\\]")
	extlinks_re.compile("\\[http[^\\s]*\\s(.*?)\\]")
	em_re.compile("'{2,}")
	tag_re.compile("<[^>]+>")
	whitespace_re.compile("[\t ]+")
	nl_re.compile("\n+")
	alt_re.compile("alt=(.+?)\\|")
	#image_field_re.compile("(photo|image\\|?)[^_\\|]*?=(.+?)(\\||$)")
	image_field_re.compile("[\\|=]\\s*([^|=]+\\.\\w{,4})")
	#image_field_re.compile("photo")
	tokenizer.compile("[^\\{\\}\\[\\]<>]+|[\\{\\}\\[\\]<>]")
	image_name_re.compile("^([iI]mage:|[fF]ile:)")

static func _seeded_shuffle(seed, arr, bias=false):
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(seed)
	if not bias:
		Util.shuffle(rng, arr)
	else:
		Util.biased_shuffle(rng, arr, 2.0)

static func _to_link_case(s):
	if len(s) > 0:
		return s[0].to_upper() + s.substr(1)
	else:
		return ""

static func _add_text_item(items, title, subtitle, text):
	if (
		not ignore_sections.has(title.to_lower().strip_edges()) and
		len(text) > 20
	):
		var t = ((section_fmt % subtitle) + "\n" + text) if subtitle != "" else text
		items.append({
			"type": "rich_text",
			"material": "marble",
			"text": text_item_fmt % [title, t]
		})

static func _clean_section(s):
	return s.replace("=", "").strip_edges()

static var trim_filename_front = len("File:")
static func _clean_filename(s):
	return IMAGE_REGEX.sub(s.substr(trim_filename_front), "")

static func _create_text_items(title, extract):
	var items = []
	var lines = extract.split("\n")

	var current_title = title
	var current_subtitle = ""
	var current_text = ""

	for line in lines:
		var over_lim = len(current_text) > max_len_soft
		if line == "":
			continue
		elif s2_re.search(line):
			_add_text_item(items, current_title, current_subtitle, current_text)
			current_title = _clean_section(line)
			current_subtitle = ""
			current_text = ""
		else:
			if line.begins_with("="):
				var sec = section_fmt % _clean_section(line)
				if len(current_text) + len(sec) > max_len_soft:
					_add_text_item(items, current_title, current_subtitle, current_text)
					current_subtitle = _clean_section(line)
					current_text = ""
				else:
					current_text += sec
			elif not over_lim:
				current_text += p_fmt % line

	_add_text_item(items, current_title, current_subtitle, current_text)

	return items

static func _wikitext_to_extract(wikitext):
	wikitext = template_re.sub(wikitext, "", true)
	wikitext = links_re.sub(wikitext, "$2", true)
	wikitext = extlinks_re.sub(wikitext, "$1", true)
	wikitext = em_re.sub(wikitext, "", true)
	wikitext = tag_re.sub(wikitext, "", true)
	wikitext = whitespace_re.sub(wikitext, " ", true)
	wikitext = nl_re.sub(wikitext, "\n", true)
	return wikitext.strip_edges()

static func _parse_wikitext(wikitext):
	var tokens = tokenizer.search_all(wikitext)
	var link = ""
	var links = []

	var depth_chars = {
		"<": ">",
		"[": "]",
		"{": "}",
	}

	var depth = []
	var dc
	var dl
	var in_link
	var t
	var in_tag
	var tag = ""
	var html_tag = null
	var html = []
	var template = []
	var in_template

	for match in tokens:
		t = match.get_string(0)
		dc = depth_chars.get(t)
		dl = len(depth)
		in_link = dl > 1 and depth[0] == "]" and depth[1] == "]"
		in_tag = dl > 0 and depth[dl - 1] == ">"
		in_template = dl > 1 and depth[0] == "}" and depth[1] == "}"

		if dc:
			depth.push_back(dc)
		elif dl == 0:
			if html_tag:
				html.append(t)
		elif t == depth[dl - 1]:
			depth.pop_back()
		elif in_tag:
			tag += t
		elif in_link:
			link += t
		elif in_template:
			template.append(t)

		if not in_link and len(link) > 0:
			links.append(["link", link])
			link = ""

		if not in_template and len(template) > 0:
			links.append(["template", "".join(template)])
			template.clear()

		if not in_tag and len(tag) > 0:
			# we don't handle nested tags for now
			if tag[0] == "!" or tag[len(tag) - 1] == "/":
				pass
			elif not tag[0] == "/":
				html_tag = tag
			else:
				if len(html) > 0 and html_tag.strip_edges().begins_with("gallery"):
					var html_str = "".join(html)
					var lines = html_str.split("\n")
					for line in lines:
						links.append(["link", line])
				html.clear()
				html_tag = null
			tag = ""

	return links

static func commons_image_to_item(title):
	return {
		"type": "image",
		"title": title,
		"text": _clean_filename(title),
	}

static func create_items(title, result, prev_title=""):
	var items = []
	var doors = []
	var doors_used = {}

	if result and result.has("wikitext") and result.has("extract"):
		var wikitext = result.wikitext

		Util.t_start()
		var links = _parse_wikitext(wikitext)
		Util.t_end("_parse_wikitext")

		# we are using the extract returned from API until my parser works better
		items.append_array(_create_text_items(title, result.extract))

		for link_entry in links:
			var type = link_entry[0]
			var link = link_entry[1]

			var target = _to_link_case(image_name_re.sub(link.get_slice("|", 0), "File:"))
			var caption = alt_re.search(link)

			if target.begins_with("File:"):
				items.append({
					"type": "image",
					"title": target,
					"text": caption.get_string(1) if caption else _clean_filename(target),
				})

			elif type == "template":
				var other_images = image_field_re.search_all(link)
				if len(other_images) > 0:
					for match in other_images:
						var image_title = image_name_re.sub(match.get_string(1), "File:")
						if not image_title or not IMAGE_REGEX.search(image_title):
							continue
						if not image_title.begins_with("File:"):
							image_title = "File:" + image_title
						items.append({
							"type": "image",
							"title": image_title,
							"text": caption.get_string(1) if caption else _clean_filename(image_title),
						})

			elif type == "link" and target and target.find(":") < 0:
				var door = _to_link_case(target.get_slice("#", 0))
				if not doors_used.has(door) and door != title and door != prev_title:
					doors.append(door)
					doors_used[door] = true

	# keep first item and first door intact
	var front_item = items.pop_front()
	var front_door = doors.pop_front()
	_seeded_shuffle(title + ":items", items)
	_seeded_shuffle(title + ":doors", doors, true)
	items.push_front(front_item)
	doors.push_front(front_door)

	return {
		"doors": doors,
		"items": items,
	}
