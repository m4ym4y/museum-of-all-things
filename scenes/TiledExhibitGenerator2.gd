@tool
extends Node3D

# params
#   min_room_dimension: int
#   max_room_dimension: int
#   theme: str | "default"
#   start_pos: Vector3
#   title: str
#   prev_title: str
#   hall_type: Array[2] | [true, 0]
#   no_props (?): boolean
#   exit_limit: int

const FLOOR_WOOD = 0
const RESERVED_VAL = 1
const FLOOR_CARPET = 11
const FLOOR_MARBLE = 12

const WALL = 5
const CEILING = 3
const INTERNAL_HALL = 7
const INTERNAL_HALL_TURN = 6
const HALL_STAIRS_UP = 16
const HALL_STAIRS_DOWN = 17
const HALL_STAIRS_TURN = 18
const MARKER = 8
const BENCH = 9
const FREE_WALL = 10

const BAROQUE_WALL = 19
const BAROQUE_CEILING = 20
const BAROQUE_FLOOR = 21

const THEMES = {
  "default": {
    "wall": WALL,
    "floor": FLOOR_WOOD,
    "ceiling": CEILING,
  },
  "baroque": {
    "wall": BAROQUE_WALL,
    "floor": BAROQUE_FLOOR,
    "ceiling": BAROQUE_CEILING,
  },
}

@onready var _fgrid = $FloorTiles
@onready var _wgrid = $WallTiles

# set from params
var _theme
var _min_room_dimension
var _max_room_dimension

# just member state
var _areas_reserved = []
var _areas_created = []

func generate(
    params
  ):
    _theme = THEMES[params.theme]
    _min_room_dimension = params.min_room_dimension
    _max_room_dimension = params.max_room_dimension

    for i in range(10):
      add_room()

func _rdim():
  return (randi() % (_max_room_dimension - _min_room_dimension)) + _min_room_dimension

func _rdim_hall():
  return (randi() % (_min_room_dimension - 1)) + 1

func _normalize_rect(rect):
  var p1 = rect[0]
  var p2 = rect[1]
  var c1 = Vector3(min(p1.x, p2.x), 0, min(p1.z, p2.z))
  var c2 = Vector3(max(p1.x, p2.x), 0, max(p1.z, p2.z))
  return [c1, c2]

func _expand_rect(_rect, n):
  var rect = _normalize_rect(_rect)
  var c1 = rect[0]
  var c2 = rect[1]
  return [
    Vector3(c1.x - n, 0, c1.z - n),
    Vector3(c2.x + n, 0, c2.z + n)
  ]

func _is_in_rect(p, _rect):
  var rect = _normalize_rect(_rect)
  var c1 = rect[0]
  var c2 = rect[1]
  return (p.x >= c1.x and p.x <= c2.x) and (p.z >= c1.z and p.z <= c2.z)

func _intersecting_rect(_r1, _r2):
  var r1 = _normalize_rect(_r1)
  var r2 = _normalize_rect(_r2)
  var overlap_x = r1[0].x < r2[1].x and r2[0].x < r1[1].x
  var overlap_z = r1[0].z < r2[1].z and r2[0].z < r1[1].z
  return overlap_x and overlap_z

func _left90(v):
  return v.rotated(Vector3.UP, deg_to_rad(90))

func _right90(v):
  return v.rotated(Vector3.UP, deg_to_rad(-90))

func _left_half(dimension):
  return floor(dimension / 2)

func _right_half(dimension):
  return floor((dimension - 1) / 2)

func _rect_anchor_points(_rect):
  var rect = _normalize_rect(_rect)
  var c1 = rect[0]
  var c2 = rect[1]

  # round anchor points to the right
  # to accomodate for left_half/right_half split
  return [
    {
      "dir": Vector3.LEFT,
      "p": Vector3(c1.x, 0, floor((c1.z + c2.z - 1) / 2))
    },
    {
      "dir": Vector3.FORWARD,
      "p": Vector3(floor((c1.x + c2.x + 1) / 2), 0, c1.z)
    },
    {
      "dir": Vector3.RIGHT,
      "p": Vector3(c2.x, 0, floor((c1.z + c2.z + 1) / 2))
    },
    {
      "dir": Vector3.BACK,
      "p": Vector3(floor((c1.x + c2.x - 1) / 2), 0, c2.z)
    }
  ]

func _fill_floor(_rect):
  var rect = _normalize_rect(_rect)
  var c1 = rect[0]
  var c2 = rect[1]
  for x in range(c1.x, c2.x + 1):
    for z in range(c1.z, c2.z + 1):
      _fgrid.set_cell_item(Vector3(x, 0, z), _theme.floor)

func _extend_rect_from_point(start, dir, length, width):
  var c1 = start + _left90(dir) * _left_half(width)
  var c2 = start + _right90(dir) * _right_half(width) + dir * length
  return [c1, c2]

func _valid_placement(rect):
  for area in _areas_reserved:
    if _intersecting_rect(rect, area.room) or _intersecting_rect(rect, area.hall):
      return false
  for area in _areas_created:
    if _intersecting_rect(rect, area.room):
      return false
    # start area does not have a hall
    if area.hall and _intersecting_rect(rect, area.hall):
      return false
  return true

func add_room():
  var room = null
  var hall = null
  if len(_areas_reserved) == 0:
    # room reserved initial could be added in generate
    room = _extend_rect_from_point(Vector3.ZERO, Vector3.FORWARD, _rdim(), _rdim())
  else:
    var reservation = _areas_reserved.pop_at(randi() % len(_areas_reserved))
    room = reservation.room
    hall = reservation.hall

  # scope out the next rooms
  var anchors = _rect_anchor_points(room)
  for anchor in anchors:
    # todo: random hall widths
    var try_hall = _extend_rect_from_point(anchor.p, anchor.dir, 3, _rdim_hall())
    var try_hall_anchors = _rect_anchor_points(try_hall)

    # place room in the same direction hallway is going
    var try_room_start
    for a in try_hall_anchors:
      if a.dir == anchor.dir:
        try_room_start = a.p

    # todo random room sizes
    var try_room = _extend_rect_from_point(try_room_start, anchor.dir, _rdim(), _rdim())
    if _valid_placement(try_hall) and _valid_placement(try_room):
      _areas_reserved.push_back({ "room": try_room, "hall": try_hall })

  # actually write them to the gridmap
  _areas_created.push_back({ "room": room, "hall": hall })
  _fill_floor(room)
  if hall:
    _fill_floor(hall)
