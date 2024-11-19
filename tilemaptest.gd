@tool
extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  $TiledExhibitGenerator.generate(
      min_room_width,
      max_room_width,
      min_room_length,
      max_room_length,
      room_count
  )
  pass # Replace with function body.

func _input(event):
  if event.is_action_pressed("ui_cancel"):
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  if event.is_action_pressed("click"):
    if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
      Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
  pass

@export var min_room_width: int = 2
@export var max_room_width: int = 5
@export var min_room_length: int = 2
@export var max_room_length: int = 5
@export var room_count: int = 4

@export var click: bool = false:
  set(new_value):
    _regenerate_map()

func _regenerate_map():
  $TiledExhibitGenerator.generate(
      min_room_width,
      max_room_width,
      min_room_length,
      max_room_length,
      room_count
  )
