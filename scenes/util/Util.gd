extends Node

const FLOOR_WOOD = 0
const FLOOR_CARPET = 11
const FLOOR_MARBLE = 12

func vecToRot(vec):
  if vec.z < -0.1:
    return 0.0
  elif vec.z > 0.1:
    return PI
  elif vec.x > 0.1:
    return 3 * PI / 2
  elif vec.x < -0.1:
    return PI / 2
  return 0.0

func vecToOrientation(grid, vec):
  var vec_basis = Basis.looking_at(vec.normalized())
  return grid.get_orthogonal_index_from_basis(vec_basis)

func gridToWorld(vec):
  return 4 * vec

func worldToGrid(vec):
  return (vec / 4.0).round()

func coalesce(a, b):
  return a if a else b

func clear_listeners(n, sig_name):
  var list = n.get_signal_connection_list(sig_name)
  for c in list:
    c.signal.disconnect(c.callable)

func is_xr():
  return ProjectSettings.get_setting_with_override("xr/openxr/enabled")

func is_compatibility_renderer():
  return RenderingServer.get_current_rendering_method() == 'gl_compatibility'

func normalize_url(url):
  if url.begins_with('//'):
    return 'https:' + url
  else:
    return url

# it is intentional that these line up
var FLOOR_LIST = [FLOOR_WOOD, FLOOR_MARBLE, FLOOR_CARPET]
var FOG_LIST   = [Color.WHITE, Color.WHITE, Color.BLACK ]

# weighted towards wood
var ITEM_MATERIAL_LIST = ["wood", "marble", "none"]
var PLATE_STYLE_LIST = ["white", "black"]

func gen_floor(title):
  return FLOOR_LIST[hash(title) % len(FLOOR_LIST)]

func gen_fog(title):
  return FOG_LIST[hash(title) % len(FOG_LIST)]

func gen_item_material(title):
  return ITEM_MATERIAL_LIST[hash(title + ":material") % len(ITEM_MATERIAL_LIST)]

func gen_plate_style(title):
  var material = gen_item_material(title)
  if material == "none":
    return "white"
  return null

var _time_start = 0
func t_start():
  _time_start = Time.get_ticks_usec()

func t_end(msg):
  var _time_end = Time.get_ticks_usec()
  var elapsed = _time_end - _time_start
  print("elapsed=%s msg=%s" % [elapsed / 1000000.0, msg])

func cell_neighbors(grid, pos, id):
  var neighbors = []
  for x in range(-1, 2):
    for z in range(-1, 2):
      # no diagonals
      if x != 0 and z != 0:
        continue
      elif x == 0 and z == 0:
        continue

      var vec = Vector3(pos.x + x, pos.y, pos.z + z)
      var cell_val = grid.get_cell_item(vec)

      if cell_val == id:
        neighbors.append(vec)
  return neighbors

func only_types_in_cells(grid, cells, types, p=false):
  for c in cells:
    var v = grid.get_cell_item(c)
    if not types.has(v):
      if p:
        print("returning false-- found type ", v)
      return false
  return true

func safe_overwrite(grid, pos):
  return only_types_in_cells(grid, [
    pos,
    pos - Vector3.UP,
    pos + Vector3.UP,
  ], [-1, 5])

func shuffle(rng, arr):
  var n = len(arr)
  for i in range(n - 1, 0, -1):
    var j = rng.randi() % (i + 1) # Get a random index in range [0, i]
    # Swap elements at indices i and j
    var temp = arr[i]
    arr[i] = arr[j]
    arr[j] = temp

# shuffle with bias to keep items in place
func biased_shuffle(rng, arr, sd_to_start):
  var n = len(arr)
  for i in range(n - 1, 0, -1):
    var fi = float(i)
    # use gaussian distribution to bias towards current position
    var j = roundi(clamp(rng.randfn(fi + 1.0, fi / sd_to_start), 0.0, fi))
    # Swap elements at indices i and j
    var temp = arr[i]
    arr[i] = arr[j]
    arr[j] = temp

func strip_markup(s):
  var mid = curly_tag_re.sub(s, "", true)
  return markup_tag_re.sub(mid, " ", true)

func strip_html(s):
  var mid = display_none_re.sub(s, "", true)
  return html_tag_re.sub(mid, "", true).replace("\n", " ")

func trim_to_length_sentence(s, lim):
  var pos = len(s) - 1
  while true:
    if (s.substr(pos, 2) == ". " or s[pos] == "\n") and pos < lim:
      break
    pos -= 1
    if pos < 0:
      break
  return s.substr(0, pos + 1)

var html_tag_re = RegEx.new()
var display_none_re = RegEx.new()
var markup_tag_re = RegEx.new()
var curly_tag_re = RegEx.new()
func _ready():
  display_none_re.compile("<.*?display:\\s*none.*?>.+?<.*?>")
  html_tag_re.compile("<.+?>")
  markup_tag_re.compile("\\.\\w.+? ")
  curly_tag_re.compile("\\{.+?\\}")
