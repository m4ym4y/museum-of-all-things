@tool
extends Node3D

@onready var Portal = preload("res://Portal.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  set_up_exhibit()

func vecToRot(vec):
  if vec.z < 0:
    return 0.0
  elif vec.z > 0:
    return PI
  elif vec.x > 0:
    return 3 * PI / 2
  elif vec.x < 0:
    return PI / 2
  return 0.0

func gridToWorld(vec):
  return 4 * vec

func set_up_exhibit():
  var generated_results = $TiledExhibitGenerator.generate(
      Vector3(0, 0, 0),
      min_room_dimension,
      max_room_dimension,
      room_count
  )
  return

  var entry = generated_results[0]
  var exits = generated_results[1]

  var entry_portal = Portal.instantiate()
  entry_portal.rotation.y = vecToRot(entry[1]) + PI
  entry_portal.position = gridToWorld(entry[0]) + Vector3(0, 1.5, 0)
  add_child(entry_portal)

  # add a marker at every exit
  for exit in exits:
    var exit_portal = Portal.instantiate()
    exit_portal.rotation.y = vecToRot(exit[1])
    exit_portal.position = gridToWorld(exit[0]) + Vector3(0, 1.5, 0)
    exit_portal.exit_portal = entry_portal
    add_child(exit_portal)

func _input(event):
  if event.is_action_pressed("ui_cancel"):
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
  if event.is_action_pressed("click"):
    if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
      Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
  pass

@export var min_room_dimension: int = 2
@export var max_room_dimension: int = 5
@export var room_count: int = 4

@export var regenerate_starting_exhibit: bool = false:
  set(new_value):
    _regenerate_map()

func _regenerate_map():
  $TiledExhibitGenerator.generate(
      Vector3(0, 0, 0),
      min_room_dimension,
      max_room_dimension,
      room_count
  )
