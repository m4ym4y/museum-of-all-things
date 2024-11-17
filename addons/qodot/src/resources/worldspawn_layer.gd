class_name QodotWorldspawnLayer
extends Resource

@export var name := ""
@export var texture := ""
@export var node_class := ""
@export var build_visuals := true
@export var collision_shape_type := QodotFGDSolidClass.CollisionShapeType.CONVEX # (QodotFGDSolidClass.CollisionShapeType)
@export var script_class: Script = null

func _init() -> void:
	resource_name = "Worldspawn Layer"
