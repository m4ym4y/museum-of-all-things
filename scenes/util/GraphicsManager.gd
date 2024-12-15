extends Node

var _env
var limit_fps = false
var fps_limit = 60
var _default_settings_obj

func init():
	_env = get_tree().get_nodes_in_group("Environment")[0]

	if not _env:
		push_error("could not load environment node")
		return

	_default_settings_obj = _create_settings_obj()
	var loaded_settings = _load_settings()
	if loaded_settings:
		_apply_settings(loaded_settings, _default_settings_obj)

func set_fps_limit(value: float):
	fps_limit = int(value)
	if limit_fps:
		Engine.set_max_fps(fps_limit)

func enable_fps_limit(enabled: bool):
	limit_fps = enabled
	if limit_fps:
		Engine.set_max_fps(fps_limit)

func get_env():
	# we assume that they modify the settings
	return _env.environment

func _apply_settings(s, default={}):
	var e = _env.environment
	for field in ["ssr_enabled", "ssr_max_steps", "fog_enabled"]:
		e[field] = s[field] if s.has(field) else default[field]
	set_fps_limit(s["fps_limit"] if s.has("fps_limit") else default["fps_limit"])
	enable_fps_limit(s["limit_fps"] if s.has("limit_fps") else default["limit_fps"])

func _create_settings_obj():
	var e = _env.environment
	return {
		"ssr_enabled": e.ssr_enabled,
		"ssr_max_steps": e.ssr_max_steps,
		"fog_enabled": e.fog_enabled,
		"fps_limit": fps_limit,
		"limit_fps": limit_fps,
	}

func restore_default_settings():
	_apply_settings(_default_settings_obj)

func save_settings():
	var s = _create_settings_obj()
	var json_text = JSON.stringify(s)
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	file.store_string(json_text)
	file.close()

func _load_settings():
	var file = FileAccess.open("user://settings.json", FileAccess.READ)
	if not file:
		return null
	var json_text = file.get_as_text()
	file.close()
	return JSON.parse_string(json_text)
