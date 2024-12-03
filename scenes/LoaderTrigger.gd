extends Area3D

@onready var loaded = false;
@onready var _xr = Util.is_xr()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if _xr:
		$CollisionShape3D.scale = Vector3.ONE * 8

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
