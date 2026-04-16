extends Node3D

signal loaded

const PLINTH_HEIGHT = 1.0
const PLINTH_DEPTH = 0.4
const SCULPTURE_SIZE = 0.75
const SHELF_HEIGHT = 0.04
const LABEL_MARGIN = 0.05

@onready var _marble_material = preload("res://assets/textures/marble21.tres")
@onready var _white_material = preload("res://assets/textures/flat_white.tres")
@onready var _black_material = preload("res://assets/textures/black.tres")
@onready var _label_font = preload("res://assets/fonts/CormorantGaramond/CormorantGaramond-Bold.ttf")

var stl_url: String
var title: String
var text: String

@onready var _sculpture_instance: MeshInstance3D = $SculptureInstance
@onready var _light: SpotLight3D = $Light
var _label: Label3D
var _label_plate: MeshInstance3D
var _sculpture_material: StandardMaterial3D

func _ready():
  _build_sculpture_material()
  _build_label()
  call_deferred("_orient_light")
  visible = false


func _build_sculpture_material():
  _sculpture_material = _marble_material.duplicate()
  _sculpture_material.uv1_triplanar = true
  _sculpture_material.uv1_triplanar_sharpness = 4.0
  _sculpture_material.uv1_scale = Vector3(2, 2, 2)
  _sculpture_material.roughness = 1.0
  _sculpture_material.metallic = 0.0


func _orient_light():
  if is_instance_valid(_light):
    _light.look_at(to_global(Vector3(0, 0.9, 0)))

func _build_label():
  _label = Label3D.new()
  _label.pixel_size = 0.002
  _label.font_size = 48
  _label.font = _label_font
  _label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  _label.width = 900
  _label.modulate = Color(0, 0, 0, 1)
  _label.outline_modulate = Color(0, 0, 0, 0)
  # On the wall, above the sculpture (wall front face is at z ≈ -0.40 in local space)
  _label.position = Vector3(0, PLINTH_HEIGHT / 2.0 + SCULPTURE_SIZE + 0.7, -0.39)
  _label.visibility_range_end = 10.0
  _label.visibility_range_end_margin = 1.0
  _label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
  _label.text = Util.strip_markup(text) if text else ""

  var plate_box = BoxMesh.new()
  plate_box.size = Vector3(1, 1, 0.01)
  _label_plate = MeshInstance3D.new()
  _label_plate.mesh = plate_box
  _label_plate.material_override = _white_material
  _label_plate.position = Vector3(0, 0, -0.009)
  _label_plate.visible = false
  _label_plate.visibility_range_end = 10.0
  _label_plate.visibility_range_end_margin = 1.0
  _label_plate.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
  _label_plate.add_to_group("render_distance")
  _label.add_child(_label_plate)

  add_child(_label)
  call_deferred("_update_label_plate")

func _update_label_plate():
  if not is_instance_valid(_label):
    return
  var aabb = _label.get_aabb()
  if aabb.size.length() == 0:
    call_deferred("_update_label_plate")
    return
  _label_plate.visible = true
  _label_plate.scale = Vector3(aabb.size.x + 2 * LABEL_MARGIN, aabb.size.y + 2 * LABEL_MARGIN, 1)
  _label_plate.position.z = -0.009

func _on_mesh_loaded(url: String, mesh: ArrayMesh, _ctx):
  if url != stl_url:
    return
  DataManager.loaded_mesh.disconnect(_on_mesh_loaded)
  if not is_instance_valid(_sculpture_instance):
    return

  _sculpture_instance.mesh = mesh

  var aabb = mesh.get_aabb()
  _sculpture_instance.position = Vector3(
    0,
    (PLINTH_HEIGHT / 2.0 + SHELF_HEIGHT) - aabb.position.y + 0.01,
    0
  )

  var shelf_top = PLINTH_HEIGHT / 2.0 + SHELF_HEIGHT
  var first_surface = _find_first_central_surface(mesh)
  var first_surface_y = _sculpture_instance.position.y + first_surface.y
  if first_surface_y > shelf_top + 0.02:
    _build_support_rod(shelf_top, first_surface_y, Vector2(first_surface.x, first_surface.z))

  _sculpture_instance.material_override = _sculpture_material
  _sculpture_instance.visibility_range_end = 25.0
  _sculpture_instance.visibility_range_end_margin = 5.0
  _sculpture_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
  _sculpture_instance.add_to_group("render_distance")
  _sculpture_instance.visible = true

  if Util.is_compatibility_renderer():
    _light.visible = false
  else:
    create_tween().tween_property(_light, "light_energy", 0.8, 0.5)

  add_to_group("loaded_sculpture")
  visible = true
  emit_signal("loaded")


func _on_data_complete(files, _ctx):
  if files.has(title):
    var data = ExhibitFetcher.get_result(title)
    if data:
      ExhibitFetcher.images_complete.disconnect(_on_data_complete)
      ExhibitFetcher.commons_images_complete.disconnect(_on_data_complete)
      _apply_data(data)

func _apply_data(data):
  if data.has("image_description"):
    text = Util.strip_html(data.image_description)
  if data.has("license_short_name") and data.has("artist"):
    text += "\n" + data.license_short_name + " " + Util.strip_html(data.artist)
  if is_instance_valid(_label):
    _label.text = text
    call_deferred("_update_label_plate")
  if not stl_url and data.has("stl_url"):
    stl_url = data.stl_url
    DataManager.loaded_mesh.connect(_on_mesh_loaded)
    DataManager.request_stl(stl_url, SCULPTURE_SIZE)

# Returns Vector3(h_x, mesh_y, h_z) — the horizontal position and lowest surface y found.
# Tries wall-side offsets first (negative Z = toward wall), falls back to center.
func _find_first_central_surface(mesh: ArrayMesh) -> Vector3:
  var arrays = mesh.surface_get_arrays(0)
  var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  for h in [Vector2(0, -0.1), Vector2(0, -0.05), Vector2.ZERO]:
    var min_y = INF
    for v in verts:
      if Vector2(v.x - h.x, v.z - h.y).length() < 0.1:
        min_y = minf(min_y, v.y)
    if not is_inf(min_y):
      return Vector3(h.x, min_y, h.y)
  return Vector3(0, mesh.get_aabb().position.y, 0)

func _build_support_rod(bottom_y: float, top_y: float, h_pos: Vector2):
  var height = top_y - bottom_y
  var cyl = CylinderMesh.new()
  cyl.top_radius = 0.006
  cyl.bottom_radius = 0.006
  cyl.height = height
  var rod = MeshInstance3D.new()
  rod.mesh = cyl
  rod.material_override = _black_material
  rod.position = Vector3(h_pos.x, bottom_y + height / 2.0, h_pos.y)
  rod.visibility_range_end = 25.0
  rod.visibility_range_end_margin = 5.0
  rod.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
  rod.add_to_group("render_distance")
  add_child(rod)

func init(_title: String, _text: String):
  title = _title
  text = _text

  var data = ExhibitFetcher.get_result(title)
  if data:
    _apply_data(data)
  else:
    ExhibitFetcher.images_complete.connect(_on_data_complete)
    ExhibitFetcher.commons_images_complete.connect(_on_data_complete)
