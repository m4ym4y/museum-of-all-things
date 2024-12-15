extends Control

signal resume

@onready var env = get_tree().get_nodes_in_group("Environment")[0]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _on_visibility_changed():
	if visible:
		$MarginContainer/VBoxContainer/Button.grab_focus()

func _on_resume_pressed():
	emit_signal("resume")

func _on_reflection_quality_value_changed(value: float):
	env.environment.ssr_max_steps = int(value)

func _on_enable_reflections_toggled(toggled_on: bool):
	env.environment.ssr_enabled = toggled_on

var _fps_limit = 60
var _limit_fps = false

func _on_max_fps_value_changed(value: float):
	_fps_limit = int(value)
	if _limit_fps:
		Engine.set_max_fps(_fps_limit)

func _on_limit_fps_toggled(toggled_on: bool):
	_limit_fps = toggled_on
	if _limit_fps:
		Engine.set_max_fps(_fps_limit)

func _on_enable_fog_toggled(toggled_on: bool):
	env.environment.fog_enabled = toggled_on

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
