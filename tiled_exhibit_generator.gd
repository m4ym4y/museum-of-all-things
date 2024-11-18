@tool
extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
  pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
@export var exhibit_width: int = 20
@export var exhibit_height: int = 10

@export var click: bool = false:
  set(new_value):
    _on_new_size()

func _process(delta: float) -> void:
  pass

# gen 10x10 exhibit
var size = 10

func cell_neighbors(grid, pos, id):
  var neighbors = false
  for x in range(-1, 2):
    for z in range(-1, 2):
      # no diagonals
      if x != 0 and z != 0:
        continue

      print("check for cell", pos)
      print("check x ", x, " y ", pos.y, " z ", z)
      var cell_val = grid.get_cell_item(Vector3(pos.x + x, pos.y, pos.z + z))
      print("cell val ", cell_val)

      # does not border if it contains this id
      if x == 0 and z == 0 and cell_val == id:
        print("return false")
        return false
      elif cell_val == id:
        print("return true")
        neighbors = true
  return neighbors

const FLOOR = 0
const WALL = 4
const CEILING = 3

func _on_new_size():
  var grid = $GridMap
  grid.clear()
  print("Generating new exhibit layout")

  var exhibit_map = generate_dungeon(exhibit_width, exhibit_height, 2)
  for x in range(len(exhibit_map)):
    var row = exhibit_map[x]
    for z in range(len(row)):
      var cell = row[z]
      if cell == 'F':
        grid.set_cell_item(Vector3(x, -1, z), FLOOR, 0)
        grid.set_cell_item(Vector3(x, 1, z), CEILING, 0)
      elif cell == 'W':
        grid.set_cell_item(Vector3(x, 0, z), WALL, 0)

# Create a grid initialized with a specific value
func create_grid(width: int, height: int, fill_value: String) -> Array:
  var grid : Array = []
  for y in range(height):
    var row : Array = []
    for x in range(width):
      row.append(fill_value)
    grid.append(row)
  return grid

# Check if a coordinate is within bounds of the grid
func is_within_bounds(x: int, y: int, width: int, height: int) -> bool:
  return x >= 0 and x < width and y >= 0 and y < height

# Carve out a room by setting the tiles within the given bounds to floors
func carve_room(grid: Array, x1: int, y1: int, x2: int, y2: int) -> void:
  for y in range(y1, y2):
    for x in range(x1, x2):
      grid[y][x] = "F"  # F for Floor

# Mark all tiles bordering a floor as walls
func add_walls(grid: Array) -> void:
  var height : int = grid.size()
  var width : int = grid[0].size()
  for y in range(height):
    for x in range(width):
      if grid[y][x] == "F":  # Only add walls near floors
        for dy in range(-1, 2):
          for dx in range(-1, 2):
            var nx : int = x + dx
            var ny : int = y + dy
            if is_within_bounds(nx, ny, width, height) and grid[ny][nx] == " ":
              grid[ny][nx] = "W"  # W for Wall

# Replace floor tiles on the edges of the map with walls
func replace_edge_floors(grid: Array) -> void:
  var height : int = grid.size()
  var width : int = grid[0].size()
  for x in range(width):
    if grid[0][x] == "F":
      grid[0][x] = "W"
    if grid[height - 1][x] == "F":
      grid[height - 1][x] = "W"
  for y in range(height):
    if grid[y][0] == "F":
      grid[y][0] = "W"
    if grid[y][width - 1] == "F":
      grid[y][width - 1] = "W"

# Create a hallway connecting two points
func create_hallway(grid: Array, x1: int, y1: int, x2: int, y2: int) -> void:
  if randf() > 0.5:
    # Horizontal first
    for x in range(min(x1, x2), max(x1, x2) + 1):
      grid[y1][x] = "F"
    for y in range(min(y1, y2), max(y1, y2) + 1):
      grid[y][x2] = "F"
  else:
    # Vertical first
    for y in range(min(y1, y2), max(y1, y2) + 1):
      grid[y][x1] = "F"
    for x in range(min(x1, x2), max(x1, x2) + 1):
      grid[y2][x] = "F"

# Split a partition into two sub-partitions
func split_partition(x1: int, y1: int, x2: int, y2: int, min_size: int) -> Array:
  var width : int = x2 - x1
  var height : int = y2 - y1
  if width > height:  # Split vertically
    var split : int = randi_range(x1 + min_size, x2 - min_size)
    return [[x1, y1, split, y2], [split, y1, x2, y2]]
  else:  # Split horizontally
    var split : int = randi_range(y1 + min_size, y2 - min_size)
    return [[x1, y1, x2, split], [x1, split, x2, y2]]

# Generate rooms using BSP
func generate_bsp(grid: Array, x1: int, y1: int, x2: int, y2: int, min_size: int, rooms: Array) -> void:
  if x2 - x1 < 2 * min_size or y2 - y1 < 2 * min_size:
    # Carve a room within this partition
    var room_width : int = randi_range(min_size, x2 - x1)
    var room_height : int = randi_range(min_size, y2 - y1)
    var rx : int = randi_range(x1, x2 - room_width)
    var ry : int = randi_range(y1, y2 - room_height)
    carve_room(grid, rx, ry, rx + room_width, ry + room_height)
    var room_center : Array = [rx + room_width / 2, ry + room_height / 2]
    rooms.append(room_center)
    return

  # Split the partition into two
  var partitions : Array = split_partition(x1, y1, x2, y2, min_size)
  generate_bsp(grid, partitions[0][0], partitions[0][1], partitions[0][2], partitions[0][3], min_size, rooms)
  generate_bsp(grid, partitions[1][0], partitions[1][1], partitions[1][2], partitions[1][3], min_size, rooms)

func find(parent, u: int) -> int:
  if parent[u] != u:
    parent[u] = find(parent, parent[u])
  return parent[u]

# Connect all rooms using a minimum spanning tree (MST)
func connect_rooms(grid: Array, rooms: Array) -> void:
  var edges : Array = []
  for i in range(rooms.size()):
    for j in range(rooms.size()):
      if i != j:
        var x1 : int = rooms[i][0]
        var y1 : int = rooms[i][1]
        var x2 : int = rooms[j][0]
        var y2 : int = rooms[j][1]
        var distance : float = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2))
        edges.append([distance, i, j])
  edges.sort()

  var parent : Array = []
  for i in range(rooms.size()):
    parent.append(i)

  var union = func(u: int, v: int) -> void:
    var root_u : int = find(parent, u)
    var root_v : int = find(parent, v)
    if root_u != root_v:
      parent[root_u] = root_v

  for edge in edges:
    var i : int = edge[1]
    var j : int = edge[2]
    if find(parent, i) != find(parent, j):
      union.call(i, j)
      create_hallway(grid, rooms[i][0], rooms[i][1], rooms[j][0], rooms[j][1])

# Main function to generate the dungeon
func generate_dungeon(width: int, height: int, min_room_size: int) -> Array:
  var grid : Array = create_grid(width, height, " ")  # Initialize grid with empty spaces
  var rooms : Array = []
  generate_bsp(grid, 0, 0, width, height, min_room_size, rooms)
  connect_rooms(grid, rooms)
  add_walls(grid)
  replace_edge_floors(grid)
  return grid
