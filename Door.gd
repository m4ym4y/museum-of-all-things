extends Spatial

signal open

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func init(name):
	$Label3D.text = name

#TODO: cooldown timer
var interacted = false
func interact():
	if not interacted:
		interacted = true
		print("DOOR INTERACT TRIGGER")
		emit_signal("open")
		translation.y -= 10
		# yield(get_tree().create_timer(5), "timeout")
		# interacted = false
		# translation.y += 10

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
