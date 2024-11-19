@tool
extends Node3D

@onready var portal = preload("res://Portal.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  pass # Replace with function body.

func _process(delta: float) -> void:
  pass

func cell_neighbors(grid, pos, id):
  var neighbors = []
  for x in range(-1, 2):
    for z in range(-1, 2):
      # no diagonals
      if x != 0 and z != 0:
        continue
      elif x == 0 and z == 0:
        continue

      var vec = Vector3(pos.x + x, pos.y, pos.z + z)
      var cell_val = grid.get_cell_item(vec)

      if cell_val == id:
        neighbors.append(vec)
  return neighbors

const FLOOR = 0
const WALL = 5
const CEILING = 3
const INTERNAL_HALL = 7
const INTERNAL_HALL_TURN = 6

const DIRECTIONS = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, -1)]
# const DIRECTIONS = [Vector3(1, 0, 0), Vector3(0, 0, 1)]

func vlt(v1, v2):
  return v1 if v1.x < v2.x or v1.z < v2.z else v2

func vgt(v1, v2):
  return v1 if v1.x > v2.x or v1.z > v2.z else v2

func generate(min_room_width, max_room_width, min_room_length, max_room_length, room_count):
  var grid = $GridMap
  grid.clear()
  print("Generating new exhibit layout")

  var room_center = Vector3(0, 0, 0)
  var room_width = randi_range(min_room_width, max_room_width)
  var room_length = randi_range(min_room_length, max_room_length)
  var next_room_direction
  var next_room_width
  var next_room_length
  var next_room_center

  var room_list = []
  var branch_point_list = []

  for room in range(room_count):
    var room_entry = {
      "center": room_center,
      "width": room_width,
      "length": room_length
    }
    branch_point_list.append(room_entry)
    room_list.append(room_entry)

    var bounds = room_to_bounds(room_center, room_width, room_length)
    carve_room(grid, bounds[0], bounds[1], 0)

    var early_terminate = true
    for nop_ in range(10):
      next_room_direction = DIRECTIONS[randi() % len(DIRECTIONS)]
      next_room_width = randi_range(min_room_width, max_room_width)
      next_room_length = randi_range(min_room_length, max_room_length)
      next_room_center = room_center + Vector3(
        next_room_direction.x * (room_width / 2 + next_room_width / 2 + 2),
        0,
        next_room_direction.z * (room_length / 2 + next_room_length / 2 + 2)
      )

      var new_bounds = room_to_bounds(next_room_center, next_room_width, next_room_length)
      if not overlaps_room(grid, new_bounds[0], new_bounds[1], 0):
        early_terminate = false
        break

    if early_terminate:
      # discard this room
      room_list.pop_back()
      branch_point_list.pop_back()
      var prev_room = branch_point_list.pop_back()
      if prev_room == null:
        return
      room_center = prev_room["center"]
      room_width = prev_room["width"]
      room_length = prev_room["length"]
      continue

    if room < room_count - 1:
      var start_hall = vlt(room_center, next_room_center)
      var end_hall = vgt(room_center, next_room_center)
      var width = randi_range(1, min(room_width, next_room_width))
      carve_room(
          grid,
          start_hall - Vector3(width / 2, 0, width / 2),
          end_hall + Vector3(width / 2 + 1, 0, width / 2 + 1),
          0
      )

    room_center = next_room_center
    room_width = next_room_width
    room_length = next_room_length

  for room in room_list:
    decorate_room(grid, room)

func decorate_room(grid, room):
  var center = room.center
  var width = room.width
  var length = room.length

  var bounds = room_to_bounds(center, width, length)
  var c1 = bounds[0]
  var c2 = bounds[1]
  var y = center.y

  # walk border of room to place wall objects
  for x in range(c1.x, c2.x + 1):
    for z in [c1.z, c2.z]:
      decorate_wall_tile(grid, Vector3(x, y, z))
  for z in range(c1.z, c2.z + 1):
    for x in [c1.x, c2.x]:
      decorate_wall_tile(grid, Vector3(x, y, z))

func vecToRot(vec):
  if vec.z < 0:
    return 0.0
  elif vec.z > 0:
    return PI
  elif vec.x > 0:
    return -PI / 2
  elif vec.x < 0:
    return PI / 2
  return 0.0

func vecToOrientation(vec):
  if vec.z < 0:
    return 0
  elif vec.z > 0:
    return 10
  elif vec.x > 0:
    return 16
  elif vec.x < 0:
    return 22
  return 0

func decorate_wall_tile(grid, pos):
  var wall_neighbors = cell_neighbors(grid, pos, WALL)
  for wall in wall_neighbors:
    var slot = (wall + pos) / 2
    # (todo) var rotation = 
    if (
        randi() % 2 == 0 and
        grid.get_cell_item(wall + (wall - pos) - Vector3(0, 1, 0)) != FLOOR and
        len(cell_neighbors(grid, wall + (wall - pos) - Vector3(0, 1, 0), FLOOR)) == 0
    ):
      var basis = Basis.looking_at((wall - pos).normalized())
      var ori = grid.get_orthogonal_index_from_basis(basis)
      grid.set_cell_item(wall, INTERNAL_HALL, ori)
      grid.set_cell_item(wall - Vector3(0, 1, 0), FLOOR, 0)
      grid.set_cell_item(wall + (wall - pos), INTERNAL_HALL_TURN, ori)
      grid.set_cell_item(wall + (wall - pos) - Vector3(0, 1, 0), FLOOR, 0)
      #var light = OmniLight3D.new()
      #light.position = Vector3(slot.x * 4, slot.y * 4 + 4, slot.z * 4) - ((wall - pos).normalized() * 2)
      #light.light_color = "#ff0000"
      #add_child(light)
      #"""var new_portal = portal.instantiate()
      #new_portal.position = Vector3(slot.x * 4, slot.y * 4 + 2, slot.z * 4) - ((wall - pos).normalized() * 0.001)
      #new_portal.exit_portal = $ExitPortal
      #new_portal.rotation.y = vecToRot(wall - pos)
      #add_child(new_portal)"""

func room_to_bounds(center, width, length):
  return [
    Vector3(center.x - width / 2, center.y, center.z - length / 2),
    Vector3(center.x + width / 2 + width % 2, center.y, center.z + length / 2 + length % 2)
  ]

func carve_room(grid, corner1, corner2, y):
  var lx = corner1.x
  var gx = corner2.x
  var lz = corner1.z
  var gz = corner2.z
  for x in range(lx - 1, gx + 1):
    for z in range(lz - 1, gz + 1):
      if x < lx or z < lz or x >= gx or z >= gz:
        if grid.get_cell_item(Vector3(x, y - 1, z)) != FLOOR:
          grid.set_cell_item(Vector3(x, y, z), WALL, 0)
          grid.set_cell_item(Vector3(x, y + 1, z), WALL, 0)
          grid.set_cell_item(Vector3(x, y + 2, z), -1, 0)
      else:
        grid.set_cell_item(Vector3(x, y, z), -1, 0)
        grid.set_cell_item(Vector3(x, y + 1, z), -1, 0)
        grid.set_cell_item(Vector3(x, y + 2, z), CEILING, 0)
        grid.set_cell_item(Vector3(x, y - 1, z), FLOOR, 0)

func overlaps_room(grid, corner1, corner2, y):
  for x in range(corner1.x, corner2.x):
    for z in range(corner1.z, corner2.z):
      var cell = grid.get_cell_item(Vector3(x, y - 1, z))
      if cell == FLOOR:
        return true
  return false
