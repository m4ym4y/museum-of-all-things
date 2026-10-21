@tool
extends Node3D

# params
#   min_room_dimension: int
#   max_room_dimension: int
#   start_pos: Vector3
#   title: str
#   prev_title: str
#   hall_type: Array[2] | [true, 0]
#   no_props (?): boolean
#   exit_limit: int

@export var HallCommon: PackedScene

@onready var _fgrid = $FloorTiles
@onready var _wgrid = $WallTiles

# set from params
var _min_room_dimension
var _max_room_dimension

# just member state
var _areas_reserved = []
var _areas_created = []
var _halls_created = []

func _m(name):
  return _fgrid.mesh_library.find_item_by_name(name)

func generate(
    params
  ):
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
  var overlap_x = r1[0].x <= r2[1].x and r2[0].x <= r1[1].x
  var overlap_z = r1[0].z <= r2[1].z and r2[0].z <= r1[1].z
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
      _fgrid.set_cell_item(Vector3(x, 0, z), _m("floor"))
      _fgrid.set_cell_item(Vector3(x, 1, z), _m("ceiling"))

func _empty_neighbors(grid, pos):
  # 1 = 0x, -z (orientation 0)
  # 2 = -x, 0z (orientation 16)
  # 4 = 0x, +z (orientation 10)
  # 8 = +x, 0z (orientation 22)
  var neighborhood_place = 1
  var neighborhood = 0
  for n in [[0, -1], [-1, 0], [0, 1], [1, 0]]:
    var x = n[0]
    var z = n[1]
    var vec = Vector3(pos.x + x, pos.y, pos.z + z)
    var cell_val = grid.get_cell_item(vec)

    if cell_val == -1:
      neighborhood += neighborhood_place
    neighborhood_place = neighborhood_place * 2
  return neighborhood

func _place_wall_if_valid(p):
  var n = _empty_neighbors(_fgrid, p)
  var wp = p
  if n == 0:
      # this is a totally enclosed floor and should have no wall
      _wgrid.set_cell_item(wp, -1)
  elif nearest_po2(n) == n: # only 1 bit is flipped if this is a power of 2, meaning 1 neighbor
      # single wall case, rotate so the wall faces the floor away from empty space
      # in single wall case we can try to place a link(hall)
      var vec = Vector3(0, 0, 0)
      var ori = 0
      var rot = PI
      if n == 1:
        vec = Vector3(0, 0, -1)
        ori = 0
        rot = PI
      elif n == 2:
        vec = Vector3(-1, 0, 0)
        ori = 16
        rot = 3 * PI / 2
      elif n == 4:
        vec = Vector3(0, 0, 1)
        ori = 10
        rot = 0
      elif n == 8:
        vec = Vector3(1, 0, 0)
        ori = 22
        rot = PI / 2

      # create the colliding rect for the link(hall)
      # this is the rect extending 2 out and 2 clockwise from p
      var hall_rect = _normalize_rect([
        p + vec,
        p + 2 * vec + vec.rotated(Vector3.UP, -PI / 2)
      ])

      # check if valid placement for link(hall)
      if vec.length() == 1 and _valid_hall_placement(hall_rect):
        var hall_obj = HallCommon.instantiate()
        hall_obj.position = 4 * ((hall_rect[0] + hall_rect[1]) / 2)
        hall_obj.rotation.y = rot
        add_child(hall_obj)

        _halls_created.push_back(hall_rect)
        _wgrid.set_cell_item(wp, _m("wall_facade"), ori)
      else:
        _wgrid.set_cell_item(wp, _m("wall_single"), ori)
  else:
      # the negative z is empty
      if n & 1 == 1:
        # if positive z is empty it's a hall
        if n & 4 == 4:
          _wgrid.set_cell_item(wp, _m("wall_internalhall"), 0)
        elif n & 2 == 2:
          _wgrid.set_cell_item(wp, _m("wall_internalcorner"), 16)
        elif n & 8 == 8:
          _wgrid.set_cell_item(wp, _m("wall_internalcorner"), 0)
      # the negative x is empty
      elif n & 2 == 2:
        # if positive x is empty too it's a hall
        if n & 8 == 8:
          _wgrid.set_cell_item(wp, _m("wall_internalhall"), 16)
        elif n & 4 == 4:
          _wgrid.set_cell_item(wp, _m("wall_internalcorner"), 10)
      else:
        _wgrid.set_cell_item(wp, _m("wall_internalcorner"), 22)
  pass

func _fill_walls(_rect):
  var rect = _normalize_rect(_rect)
  var c1 = rect[0]
  var c2 = rect[1]
  for x in range(c1.x, c2.x + 1):
    for z in [c1.z, c2.z]:
      _place_wall_if_valid(Vector3(x, 0, z))
  for z in range(c1.z, c2.z + 1):
    for x in [c1.x, c2.x]:
      _place_wall_if_valid(Vector3(x, 0, z))

func _extend_rect_from_point(start, dir, length, width):
  var c1 = start + _left90(dir) * _left_half(width)
  var c2 = start + _right90(dir) * _right_half(width) + dir * length
  return [c1, c2]

# todo: we could use a structure to prevent exhaustive search by storing areas in a map
# this would at least work for halls which are of known size and are more numerous
func _valid_placement(_rect):
  var rect = _expand_rect(_rect, 2)
  for area in _areas_reserved:
    if _intersecting_rect(rect, area.room) or _intersecting_rect(rect, area.hall):
      return false
  for area in _areas_created:
    if _intersecting_rect(rect, area.room):
      return false
    # start area does not have a hall
    if area.hall and _intersecting_rect(rect, area.hall):
      return false
  for hall in _halls_created:
    if _intersecting_rect(rect, hall):
      return false
  return true
   
# todo less code dupe
func _valid_hall_placement(rect):
  for area in _areas_reserved:
    if _intersecting_rect(rect, area.room) or _intersecting_rect(rect, area.hall):
      return false
  for area in _areas_created:
    if _intersecting_rect(rect, area.room):
      return false
    # start area does not have a hall
    if area.hall and _intersecting_rect(rect, area.hall):
      return false
  for hall in _halls_created:
    if _intersecting_rect(rect,  hall):
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
    var try_hall = _extend_rect_from_point(anchor.p, anchor.dir, 4, _rdim_hall())
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
  _fill_walls(room)
  if hall:
    _fill_floor(hall)
    _fill_walls(hall)
