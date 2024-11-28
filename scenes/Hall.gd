extends Node3D

signal on_player_toward_exit
signal on_player_toward_entry

@onready var grid_wrapper = preload("res://scenes/util/GridWrapper.tscn")
@onready var loader = $LoaderTrigger
@onready var entry_door = $EntryDoor
@onready var exit_door = $ExitDoor
@onready var _detector = $HallDirectionDetector

@onready var from_sign = $FromSign
@onready var to_sign = $ToSign
@onready var _floor

const WALL = 5
const INTERNAL_HALL = 7
const INTERNAL_HALL_TURN = 6

var _grid

var player_direction
var player_in_hall: bool:
  get:
    return _detector.player or false
  set(_value):
    pass

var from_title: String:
  get:
    return from_sign.text
  set(v):
    from_sign.text = v

var from_pos
var from_dir
var from_room_root

var to_title: String:
  get:
    return to_sign.text
  set(v):
    to_sign.text = v

var to_pos
var to_dir

func init(grid, from_title, to_title, hall_start, hall_dir, room_root = Vector3(0, 0, 0)):
  _floor = Util.gen_floor(from_title)
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
  _grid.set_cell_item(hall_start - Vector3(0, 1, 0), _floor, 0)
  _grid.set_cell_item(hall_start + Vector3(0, 1, 0), WALL, 0)
  _grid.set_cell_item(hall_corner, INTERNAL_HALL_TURN, ori)
  _grid.set_cell_item(hall_corner - Vector3(0, 1, 0), _floor, 0)

  var exit_hall_dir = hall_dir.rotated(Vector3(0, 1, 0), 3 * PI / 2)
  var exit_hall = hall_corner + exit_hall_dir
  var exit_ori = Util.vecToOrientation(_grid, exit_hall_dir)
  _grid.set_cell_item(exit_hall, INTERNAL_HALL, exit_ori)
  _grid.set_cell_item(exit_hall - Vector3(0, 1, 0), _floor, 0)
  _grid.set_cell_item(exit_hall + Vector3(0, 1, 0), WALL, 0)

  to_dir = exit_hall_dir
  to_pos = exit_hall

  from_sign.position = Util.gridToWorld(exit_hall + exit_hall_dir * 0.65) - position
  from_sign.position += exit_hall_dir.rotated(Vector3.UP, PI / 2).normalized() * 1.5
  from_sign.rotation.y = Util.vecToRot(exit_hall_dir) + 3 * PI / 4
  from_sign.text = from_title

  to_sign.position = Util.gridToWorld(hall_start - hall_dir * 0.60) - position
  to_sign.position -= hall_dir.rotated(Vector3.UP, PI / 2).normalized() * 1.5
  to_sign.rotation.y = Util.vecToRot(hall_dir) - PI / 4
  to_sign.text = to_title

  entry_door.position = Util.gridToWorld(from_pos) - 1.9 * from_dir - position
  entry_door.rotation.y = Util.vecToRot(from_dir)
  exit_door.position = Util.gridToWorld(to_pos) + 1.9 * to_dir - position
  exit_door.rotation.y = Util.vecToRot(to_dir)
  entry_door.set_open(true, true)
  exit_door.set_open(false, true)

  _detector.position = Util.gridToWorld((from_pos + to_pos) / 2) + Vector3(0, 4, 0) - position
  _detector.monitoring = true
  _detector.direction_changed.connect(_on_direction_changed)
  _detector.init(Util.gridToWorld(from_pos), Util.gridToWorld(to_pos))

func _on_direction_changed(direction):
  player_direction = direction
  if direction == "exit":
    emit_signal("on_player_toward_exit")
  else:
    emit_signal("on_player_toward_entry")
