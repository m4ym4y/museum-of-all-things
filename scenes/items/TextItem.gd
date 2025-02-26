extends Node3D

static var max_chars = 2500

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
  pass

func init(text):
  var t = Util.strip_markup(text).substr(0, max_chars)
  $Label.text = t if len(t) < max_chars else t + "..."

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#  pass
