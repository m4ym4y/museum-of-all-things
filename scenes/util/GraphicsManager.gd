extends Node

signal change_post_processing(post_processing: String)

const _settings_ns = "graphics"

var _env
var limit_fps = false
var fps_limit = 60
var _default_settings_obj
var fullscreen = false
var render_scale = 1.0
var post_processing = "none"
var render_distance_multiplier = 2.5

func init():
  _env = get_tree().get_nodes_in_group("Environment")[0]

  if not _env:
    push_error("could not load environment node")
    return

  _default_settings_obj = _create_settings_obj()
  var loaded_settings = SettingsManager.get_settings(_settings_ns)
  if loaded_settings:
    _apply_settings(loaded_settings, _default_settings_obj)

func set_fps_limit(value: float):
  fps_limit = int(value)
  if limit_fps:
    Engine.set_max_fps(fps_limit)

func set_fullscreen(_fullscreen: bool):
  fullscreen = _fullscreen
  if fullscreen:
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
  else:
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func set_render_scale(scale: float):
  render_scale = scale
  get_viewport().scaling_3d_scale = scale

func set_post_processing(_post_processing: String):
  post_processing = _post_processing
  emit_signal("change_post_processing", post_processing)

func enable_fps_limit(enabled: bool):
  limit_fps = enabled
  if limit_fps:
    Engine.set_max_fps(fps_limit)

func set_render_distance_multiplier(value: float):
  var last_distance = render_distance_multiplier
  render_distance_multiplier = value
  if not is_equal_approx(last_distance, render_distance_multiplier):
    for node in get_tree().get_nodes_in_group("render_distance"):
      node.visibility_range_end *= render_distance_multiplier / last_distance

func _on_node_added(node: Node) -> void:
  if not is_equal_approx(render_distance_multiplier, 1.0):
    if node.is_in_group("render_distance"):
      node.visibility_range_end *= render_distance_multiplier

func get_env():
  # we assume that they modify the settings
  if not _env:
    init()
  return _env.environment

func _apply_settings(s, default={}):
  var e = _env.environment
  for field in ["ssr_enabled", "ssr_max_steps", "fog_enabled", "ssil_enabled", "ambient_light_energy"]:
    e[field] = s[field] if s.has(field) else default[field]
  if Util.is_xr():
    e["ssr_enabled"] = false
  else:
    set_fps_limit(s["fps_limit"] if s.has("fps_limit") else default["fps_limit"])
    enable_fps_limit(s["limit_fps"] if s.has("limit_fps") else default["limit_fps"])
    set_fullscreen(s["fullscreen"] if s.has("fullscreen") else default["fullscreen"])
    set_render_scale(s["render_scale"] if s.has("render_scale") else default["render_scale"])
    set_post_processing(s["post_processing"] if s.has("post_processing") else default["post_processing"])
    set_render_distance_multiplier(s["render_distance_multiplier"] if s.has("render_distance_multiplier") else default["render_distance_multiplier"])

func _create_settings_obj():
  var e = _env.environment
  return {
    "ambient_light_energy": e.ambient_light_energy,
    "ssr_enabled": e.ssr_enabled,
    "ssr_max_steps": e.ssr_max_steps,
    "ssil_enabled": e.ssil_enabled,
    "fog_enabled": e.fog_enabled,
    "fps_limit": fps_limit,
    "limit_fps": limit_fps,
    "fullscreen": fullscreen,
    "render_scale": render_scale,
    "post_processing": post_processing,
    "render_distance_multiplier": render_distance_multiplier,
  }

func restore_default_settings():
  _apply_settings(_default_settings_obj)

func save_settings():
  SettingsManager.save_settings(_settings_ns, _create_settings_obj())

func _ready() -> void:
  get_tree().node_added.connect(_on_node_added)
