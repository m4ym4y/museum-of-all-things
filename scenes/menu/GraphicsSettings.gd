extends VBoxContainer

signal resume
@onready var _vbox = self
@onready var _xr = Util.is_xr()
@onready var post_processing_options = ["none", "crt"]
var _loaded_settings = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  GlobalMenuEvents._on_fullscreen_toggled.connect(_on_fullscreen_toggled)
  _load_settings()
  if _xr:
    _vbox.get_node("FPSOptions").visible = false
    _vbox.get_node("ReflectionOptions").visible = false
    _vbox.get_node("DisplayOptions").visible = false
    _vbox.get_node("PostProcessingOptions").visible = false

  if _vbox.get_node("DisplayOptions/ScaleMode").selected == 0:
    get_tree().set_group("fsr_options", "visible", false)
  else:
    _vbox.get_node("DisplayOptions/RenderScale").hide()

func ui_cancel_pressed():
  if visible:
    call_deferred("_on_resume_pressed")

func _on_visibility_changed():
  if visible and is_inside_tree():
    _load_settings()
  elif _loaded_settings and not visible:
    GraphicsManager.save_settings()

func _load_settings():
  var e = GraphicsManager.get_env()
  _loaded_settings = true

  _vbox.get_node("RenderDistanceOptions/RenderDistance").value = GraphicsManager.render_distance_multiplier
  _vbox.get_node("FPSOptions/MaxFPS").value = GraphicsManager.fps_limit
  _vbox.get_node("FPSOptions/LimitFPS").button_pressed = GraphicsManager.limit_fps
  _vbox.get_node("FPSOptions/VSync").button_pressed = GraphicsManager.vsync_enabled
  _vbox.get_node("DisplayOptions/Fullscreen").button_pressed = GraphicsManager.fullscreen
  _vbox.get_node("DisplayOptions/RenderScale").value = GraphicsManager.render_scale
  _vbox.get_node("DisplayOptions/ScaleMode").selected = GraphicsManager.scale_mode
  _vbox.get_node("DisplayOptions/FSRQuality").selected = GraphicsManager.fsr_quality
  _vbox.get_node("DisplayOptions/SharpnessScale").value = GraphicsManager.fsr_sharpness
  _vbox.get_node("ReflectionOptions/ReflectionQuality").value = e.ssr_max_steps
  _vbox.get_node("ReflectionOptions/EnableReflections").button_pressed = e.ssr_enabled
  _vbox.get_node("LightOptions/AmbientLight").value = e.ambient_light_energy
  _vbox.get_node("LightOptions/EnableSSIL").button_pressed = e.ssil_enabled
  _vbox.get_node("FogOptions/EnableFog").button_pressed = e.fog_enabled
  var post_processing = GraphicsManager.post_processing
  var idx = post_processing_options.find(post_processing)
  _vbox.get_node("PostProcessingOptions/PostProcessingEffect").select(idx if idx >= 0 else 0)

  _update_scaling()

func _on_restore_pressed():
  GraphicsManager.restore_default_settings()
  _load_settings()

func _on_resume_pressed():
  GraphicsManager.save_settings()
  emit_signal("resume")

func _on_reflection_quality_value_changed(value: float):
  GraphicsManager.get_env().ssr_max_steps = int(value)
  _vbox.get_node("ReflectionOptions/ReflectionQualityValue").text = str(int(value))

func _on_enable_reflections_toggled(toggled_on: bool):
  GraphicsManager.get_env().ssr_enabled = toggled_on

func _on_enable_ssil_toggled(toggled_on: bool):
  GraphicsManager.get_env().ssil_enabled = toggled_on

func _on_ambient_light_value_changed(value: float):
  GraphicsManager.get_env().ambient_light_energy = value
  _vbox.get_node("LightOptions/AmbientLightValue").text = "%3.2f" % value

func _on_max_fps_value_changed(value: float):
  GraphicsManager.set_fps_limit(value)
  _vbox.get_node("FPSOptions/MaxFPSValue").text = str(int(value))

func _on_limit_fps_toggled(toggled_on: bool):
  GraphicsManager.enable_fps_limit(toggled_on)

func _on_vsync_toggled(toggled_on: bool):
  GraphicsManager.set_vsync_enabled(toggled_on)

func _on_enable_fog_toggled(toggled_on: bool):
  GraphicsManager.get_env().fog_enabled = toggled_on

func _on_fullscreen_toggled(toggled_on: bool):
  GraphicsManager.set_fullscreen(toggled_on)
  _vbox.get_node("DisplayOptions/Fullscreen").set_pressed_no_signal(toggled_on)

func _update_scaling():
  var scale_mode = _vbox.get_node("DisplayOptions/ScaleMode").selected
  GraphicsManager.set_scale_mode(scale_mode)

  # Show render scale if bilinear, FSR options otherwise
  _vbox.get_node("DisplayOptions/RenderScale").visible = (scale_mode == 0)
  get_tree().set_group("fsr_options", "visible", (scale_mode != 0))

  if scale_mode == 0:  # Bilinear
    GraphicsManager.set_render_scale(_vbox.get_node("DisplayOptions/RenderScale").value)
    return

  # FSR
  var fsr_quality = _vbox.get_node("DisplayOptions/FSRQuality")
  if scale_mode == 1:  # FSR 1 has no "ultra performance"
    fsr_quality.set_item_disabled(0, false)
    fsr_quality.set_item_disabled(4, true)
  if scale_mode == 2:  # FSR 2 has no "ultra quality"
    fsr_quality.set_item_disabled(0, true)
    fsr_quality.set_item_disabled(4, false)

  GraphicsManager.set_fsr_quality(fsr_quality.selected)

  var scale = get_viewport().scaling_3d_scale
  _vbox.get_node("DisplayOptions/RenderScale").value = scale
  _vbox.get_node("DisplayOptions/RenderScaleValue").text = "%.0f %%\n" % (scale * 100)

func _on_render_scale_value_changed(value: float):
  _vbox.get_node("DisplayOptions/RenderScaleValue").text = "%d %%\n" % (value * 100)
  _update_scaling()

func _on_scale_mode_value_changed(value: int):
  match value:
    1:
      _vbox.get_node("DisplayOptions/FSRQuality").select(0)
    2:
      _vbox.get_node("DisplayOptions/FSRQuality").select(1)

  _update_scaling()

func _on_fsr_quality_item_selected(index: int) -> void:
  _update_scaling()

func _on_sharpness_scale_value_changed(value: float) -> void:
  GraphicsManager.set_fsr_sharpness(value)
  _vbox.get_node("DisplayOptions/SharpnessScaleValue").text = str(value)

func _on_pause_menu_settings() -> void:
  pass # Replace with function body.

func _on_post_processing_effect_item_selected(index: int):
  GraphicsManager.set_post_processing(post_processing_options[index])

func _on_render_distance_value_changed(value: float):
  $RenderDistanceOptions/RenderDistanceValue.text = "%dm" % int(value * 30)
  GraphicsManager.set_render_distance_multiplier(value)
