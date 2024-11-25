extends Node3D

@onready var grid_wrapper = preload("res://scenes/util/GridWrapper.tscn")
@onready var loader = $LoaderTrigger
@onready var entry_door = $EntryDoor
@onready var exit_door = $ExitDoor
@onready var detector = $HallDirectionDetector

const WALL = 5
const FLOOR = 0
const INTERNAL_HALL = 7
const INTERNAL_HALL_TURN = 6

var _grid

var from_title
var from_label
var from_pos
var from_dir
var from_room_root

var to_title
var to_label
var to_pos
var to_dir

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  pass

func get_info():
  return {
    "from_title": from_label.text,
    "from_dir": from_dir,
    "from_pos": from_pos,
    "to_title": to_label.text,
    "to_dir": to_dir,
    "to_pos": to_pos,
  }

func init(grid, from_title, to_title, hall_start, hall_dir, room_root = Vector3(0, 0, 0)):
  position = Util.gridToWorld(hall_start)
  loader.monitoring = true

  _grid = grid_wrapper.instantiate()
  _grid.init(grid)
  add_child(_grid)

  from_dir = hall_dir
  from_pos = hall_start
  from_room_root = room_root

  var ori = Util.vecToOrientation(_grid, hall_dir)
  var hall_corner = hall_start + hall_dir

  _grid.set_cell_item(hall_start, INTERNAL_HALL, ori)
  _grid.set_cell_item(hall_start - Vector3(0, 1, 0), FLOOR, 0)
  _grid.set_cell_item(hall_start + Vector3(0, 1, 0), WALL, 0)
  _grid.set_cell_item(hall_corner, INTERNAL_HALL_TURN, ori)
  _grid.set_cell_item(hall_corner - Vector3(0, 1, 0), FLOOR, 0)

  var exit_hall_dir = hall_dir.rotated(Vector3(0, 1, 0), 3 * PI / 2)
  var exit_hall = hall_corner + exit_hall_dir
  var exit_ori = Util.vecToOrientation(_grid, exit_hall_dir)
  _grid.set_cell_item(exit_hall, INTERNAL_HALL, exit_ori)
  _grid.set_cell_item(exit_hall - Vector3(0, 1, 0), FLOOR, 0)
  _grid.set_cell_item(exit_hall + Vector3(0, 1, 0), WALL, 0)

  to_dir = exit_hall_dir
  to_pos = exit_hall

  from_label = Label3D.new()
  from_label.position = Util.gridToWorld(exit_hall + exit_hall_dir * 0.51) + Vector3(0, 3.5, 0) - position
  from_label.rotation.y = Util.vecToRot(exit_hall_dir) + PI
  from_label.text = from_title
  add_child(from_label)

  to_label = Label3D.new()
  to_label.position = Util.gridToWorld(hall_start - hall_dir * 0.51) + Vector3(0, 3.5, 0) - position
  to_label.rotation.y = Util.vecToRot(hall_dir)
  to_label.text = ""
  add_child(to_label)

  entry_door.position = Util.gridToWorld(from_pos) - position
  entry_door.rotation.y = Util.vecToRot(from_dir)
  exit_door.position = Util.gridToWorld(to_pos) - position
  exit_door.rotation.y = Util.vecToRot(to_dir)
  entry_door.set_open(true)
  exit_door.set_open(true)

  detector.init(Util.gridToWorld(from_pos - from_dir), Util.gridToWorld(to_pos - to_dir))
  detector.position = Util.gridToWorld((from_pos + to_pos) / 2) - position
  detector.monitoring = true
