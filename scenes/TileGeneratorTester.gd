@tool
extends Node3D

@export var theme = "default"
var _generated = null

func _ready():
  if Engine.is_editor_hint():
    pass

func _on_generate_pressed():
  var GeneratorScene = ResourceLoader.load("res://scenes/TiledExhibitGenerator2.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
  var generator = GeneratorScene.instantiate()

  if _generated:
    _generated.queue_free()
  _generated = generator

  add_child(generator)

  generator.generate({
    "theme": "default",
    "min_room_dimension": 3,
    "max_room_dimension": 6,
  })

@export_tool_button("Generate!") var button = _on_generate_pressed
