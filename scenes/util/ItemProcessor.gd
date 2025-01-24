extends Node

signal items_complete

var ignore_sections = [
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

var IMAGE_REGEX = RegEx.new()
var s2_re = RegEx.new()
var template_re = RegEx.new()
var links_re = RegEx.new()
var extlinks_re = RegEx.new()
var em_re = RegEx.new()
var tag_re = RegEx.new()
var whitespace_re = RegEx.new()
var nl_re = RegEx.new()
var alt_re = RegEx.new()
var tokenizer = RegEx.new()
var image_name_re = RegEx.new()
var image_field_re = RegEx.new()
var exclude_image_re = RegEx.new()

var max_len_soft = 1000
var text_item_fmt = "[color=black][b][font_size=48]%s[/font_size][/b]\n\n%s"
var section_fmt = "[p][b][font_size=36]%s[/font_size][/b][/p]\n\n"
var p_fmt = "[p]%s[/p]\n\n"

var processor_thread = Thread.new()
var PROCESSOR_QUEUE = "ItemProcessor"

func _ready():
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
  image_field_re.compile("[\\|=]\\s*([^\\n|=]+\\.\\w{,4})")
  #image_field_re.compile("photo")
  tokenizer.compile("[^\\{\\}\\[\\]<>]+|[\\{\\}\\[\\]<>]")
  image_name_re.compile("^([iI]mage:|[fF]ile:)")
  exclude_image_re.compile("\\bicon\\b|\\blogo\\b|blue pencil")
  processor_thread.start(_processor_thread_loop)

func _exit_tree():
  WorkQueue.set_quitting()
  processor_thread.wait_to_finish()

func _processor_thread_loop():
  while not WorkQueue.get_quitting():
    var item = WorkQueue.process_queue(PROCESSOR_QUEUE)
    if item:
      _create_items(item[0], item[1], item[2])

func _seeded_shuffle(seed, arr, bias=false):
  var rng = RandomNumberGenerator.new()
  rng.seed = hash(seed)
  if not bias:
    Util.shuffle(rng, arr)
  else:
    Util.biased_shuffle(rng, arr, 2.0)

func _to_link_case(s):
  if len(s) > 0:
    return s[0].to_upper() + s.substr(1)
  else:
    return ""

func _add_text_item(items, title, subtitle, text):
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

func _clean_section(s):
  return s.replace("=", "").strip_edges()

var trim_filename_front = len("File:")
func _clean_filename(s):
  return IMAGE_REGEX.sub(s.substr(trim_filename_front), "")

func _create_text_items(title, extract):
  var items = []
  var lines = extract.split("\n")

  var current_title = title
  var current_subtitle = ""
  var current_text = ""
  var current_text_has_content = false

  for line in lines:
    var over_lim = len(current_text) > max_len_soft
    if line == "":
      continue
    elif s2_re.search(line):
      if current_text_has_content:
        _add_text_item(items, current_title, current_subtitle, current_text)
      current_title = _clean_section(line)
      current_subtitle = ""
      current_text = ""
      current_text_has_content = false
    else:
      if line.begins_with("="):
        var sec = section_fmt % _clean_section(line)
        if len(current_text) + len(sec) > max_len_soft and current_text_has_content:
          _add_text_item(items, current_title, current_subtitle, current_text)
          current_subtitle = _clean_section(line)
          current_text = ""
          current_text_has_content = false
        else:
          current_text += sec
      elif not over_lim:
        var stripped = line.strip_edges()
        if len(stripped) > 0:
          current_text_has_content = true
          current_text += p_fmt % stripped

  if current_text_has_content:
    _add_text_item(items, current_title, current_subtitle, current_text)

  return items

func _wikitext_to_extract(wikitext):
  wikitext = template_re.sub(wikitext, "", true)
  wikitext = links_re.sub(wikitext, "$2", true)
  wikitext = extlinks_re.sub(wikitext, "$1", true)
  wikitext = em_re.sub(wikitext, "", true)
  wikitext = tag_re.sub(wikitext, "", true)
  wikitext = whitespace_re.sub(wikitext, " ", true)
  wikitext = nl_re.sub(wikitext, "\n", true)
  return wikitext.strip_edges()

func _parse_wikitext(wikitext):
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
      # recalc whether we're in a link/tag/etc
      # not the nicest looking but it works
      dc = depth_chars.get(t)
      dl = len(depth)
      in_link = dl > 1 and depth[0] == "]" and depth[1] == "]"
      in_tag = dl > 0 and depth[dl - 1] == ">"
      in_template = dl > 1 and depth[0] == "}" and depth[1] == "}"
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
            print('adding link in gallery: ', line)
            links.append(["link", line])
        html.clear()
        html_tag = null
      tag = ""

  return links

func commons_images_to_items(title, images, extra_text):
  var items = []
  var rng = RandomNumberGenerator.new()
  var material = Util.gen_item_material(title)
  var plate = Util.gen_plate_style(title)

  rng.seed = hash(title + ":commons_shuffler")
  _seeded_shuffle(title + ":commons_images", images)

  for image in images:
    var il = len(items)
    if il > 0 and items[il - 1].type != "text":
      if len(extra_text) > 0 and rng.randi() % 2 == 0:
        items.append(extra_text.pop_front())

    if image and IMAGE_REGEX.search(image) and not exclude_image_re.search(image.to_lower()):
      items.append({
        "type": "image",
        "material": material,
        "plate": plate,
        "title": image,
        "text": _clean_filename(image),
      })

  return items

func create_items(title, result, prev_title=""):
  WorkQueue.add_item(PROCESSOR_QUEUE, [title, result, prev_title])

func _create_items(title, result, prev_title):
  var text_items = []
  var image_items = []
  var doors = []
  var doors_used = {}
  var material = Util.gen_item_material(title)
  var plate = Util.gen_plate_style(title)

  if result and result.has("wikitext") and result.has("extract"):
    var wikitext = result.wikitext

    Util.t_start()
    var links = _parse_wikitext(wikitext)
    Util.t_end("_parse_wikitext")

    # we are using the extract returned from API until my parser works better
    text_items.append_array(_create_text_items(title, result.extract))

    for link_entry in links:
      var type = link_entry[0]
      var link = link_entry[1]

      var target = _to_link_case(image_name_re.sub(link.get_slice("|", 0), "File:"))
      var caption = alt_re.search(link)

      if target.begins_with("File:") and IMAGE_REGEX.search(target):
        image_items.append({
          "type": "image",
          "material": material,
          "plate": plate,
          "title": target,
          "text": caption.get_string(1) if caption else _clean_filename(target),
        })

      elif type == "template":
        var other_images = image_field_re.search_all(link)
        if len(other_images) > 0:
          for match in other_images:
            var image_title = image_name_re.sub(match.get_string(1), "File:")
            if image_title.find("\n") >= 0:
              print("newline in file name ", image_title)
            if not image_title or not IMAGE_REGEX.search(image_title):
              continue
            if not image_title.begins_with("File:"):
              image_title = "File:" + image_title
            image_items.append({
              "type": "image",
              "material": material,
              "plate": plate,
              "title": image_title,
              "text": caption.get_string(1) if caption else _clean_filename(image_title),
            })

      elif type == "link" and target and target.find(":") < 0:
        var door = _to_link_case(target.get_slice("#", 0))
        if not doors_used.has(door) and door != title and door != prev_title and len(door) > 0:
          doors.append(door)
          doors_used[door] = true

  # keep first item and first door intact
  var front_text = text_items.pop_front()
  var front_door = doors.pop_front()
  _seeded_shuffle(title + ":text_items", text_items)
  _seeded_shuffle(title + ":image_items", image_items)
  _seeded_shuffle(title + ":doors", doors, true)
  text_items.push_front(front_text)
  doors.push_front(front_door)

  var rng = RandomNumberGenerator.new()
  rng.seed = hash(title + ":shuffler")

  # ensure that there aren't too many text items in a row
  var items = []

  if len(text_items) > 0:
    items.append(text_items.pop_front())

  while len(image_items) > 0:
    var il = len(items)
    if il > 0 and items[il - 1].type != "text":
      if len(text_items) > 0 and rng.randi() % 2 == 0:
        items.append(text_items.pop_front())
    items.append(image_items.pop_front())

  call_deferred("emit_signal", "items_complete", {
    "title": title,
    "doors": doors,
    "items": items,
    "extra_text": text_items,
  })
