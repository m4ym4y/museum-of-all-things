@tool
extends MeshInstance3D

@export_multiline var text = "[Replace me]"

func _ready() -> void:
	$SubViewport/Control/RichTextLabel.text = text
