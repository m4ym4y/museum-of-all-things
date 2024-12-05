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
	tokenizer.compile("[^\\{\\}\\[\\]<>]+|[\\{\\}\\[\\]<>]")

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
	var extract = []
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
	var link_str
	var t

	for match in tokens:
		t = match.get_string(0)
		dc = depth_chars.get(t)
		dl = len(depth)
		in_link = dl > 1 and depth[0] == "]" and depth[1] == "]"

		if dc:
			depth.push_back(dc)
		elif dl == 0:
			extract.append(t)
		elif t == depth[dl - 1]:
			depth.pop_back()
		elif in_link:
			link += t

		if not in_link and len(link) > 0:
			links.append(link)
			if not link.to_lower().begins_with("file:"):
				var ls = link.split("|")
				extract.append(ls[len(ls) - 1])
			link = ""

	return {
		"extract": "".join(extract),
		"links": links,
	}

static func create_items(title, result):
	var items = []
	var doors = []
	var doors_used = {}

	if result and result.has("wikitext"):
		var wikitext = result.wikitext
		var parsed = _parse_wikitext(wikitext)

		items.append_array(_create_text_items(title, parsed.extract))

		for link in parsed.links:
			var target = _to_link_case(link.get_slice("|", 0))
			var caption = alt_re.search(link)

			if target.begins_with("File:"):
				items.append({
					"type": "image",
					"title": target,
					"text": caption.get_string(1) if caption else target,
				})
			else:
				var door = _to_link_case(target.get_slice("#", 0))
				if not doors_used.has(door):
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
