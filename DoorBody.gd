extends StaticBody
signal try_to_open

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
var interacted = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func interact():
	if not interacted:
		interacted = true
		print("emit try to open")
		emit_signal("try_to_open", self)
		yield(get_tree().create_timer(1.0), "timeout")
		interacted = false

func open():
	print("door open", self)
	interacted = true
	$AnimationPlayer.play("slide")
	yield(get_tree().create_timer(2.0), "timeout")
	interacted = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
