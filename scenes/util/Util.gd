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

func coalesce(a, b):
	return a if a else b

func clear_listeners(n, sig_name):
	var list = n.get_signal_connection_list(sig_name)
	for c in list:
		c.signal.disconnect(c.callable)

func is_xr():
	return ProjectSettings.get_setting("xr/openxr/enabled")

func normalize_url(url):
	if url.begins_with('//'):
		return 'https:' + url
	else:
		return url

# it is intentional that these line up
var FLOOR_LIST = [FLOOR_WOOD, FLOOR_MARBLE, FLOOR_CARPET]
var FOG_LIST   = [Color.WHITE, Color.WHITE, Color.BLACK ]

func gen_floor(title):
	return FLOOR_LIST[hash(title) % len(FLOOR_LIST)]

func gen_fog(title):
	return FOG_LIST[hash(title) % len(FOG_LIST)]

var _time_start = 0
func t_start():
	_time_start = Time.get_ticks_usec()

func t_end(msg):
	var _time_end = Time.get_ticks_usec()
	var elapsed = _time_end - _time_start
	print("elapsed=%s msg=%s" % [elapsed / 1000000.0, msg])
