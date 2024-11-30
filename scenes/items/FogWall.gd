extends Node3D


func open():
	set_open(true)

func close():
	set_open(false)

func set_open(open = true, instant = false):
	$Plane.visible = not open
	if is_visible() and not instant:
		var density_tween = get_tree().create_tween()
		var opacity_tween = get_tree().create_tween()

		density_tween.tween_property(
			$FogVolume.material,
			"shader_param/density",
			0.0 if open else 1.0,
			0.5
		)
	else:
		$FogVolume.material.density = 0.0 if open else 1.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
