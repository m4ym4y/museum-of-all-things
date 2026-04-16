extends Node3D

signal loaded

const PLINTH_HEIGHT = 1.0
const PLINTH_DEPTH = 0.4
const SCULPTURE_SIZE = 0.75
const SHELF_HEIGHT = 0.04
const LABEL_MARGIN = 0.05

@onready var _marble_material = preload("res://assets/textures/marble21.tres")
@onready var _wood_material = preload("res://assets/textures/wood.tres")
@onready var _white_material = preload("res://assets/textures/flat_white.tres")
@onready var _label_font = preload("res://assets/fonts/CormorantGaramond/CormorantGaramond-Bold.ttf")

var stl_url: String
var title: String
var text: String

var _sculpture_instance: MeshInstance3D
var _label: Label3D
var _label_plate: MeshInstance3D
var _light: SpotLight3D
var _sculpture_material: StandardMaterial3D

func _ready():
  _build_sculpture_material()
  _build_plinth()
  _build_light()
  _sculpture_instance = MeshInstance3D.new()
  _sculpture_instance.visible = false
  add_child(_sculpture_instance)
  _build_label()
  visible = false

func _build_sculpture_material():
  _sculpture_material = _marble_material.duplicate()
  _sculpture_material.uv1_triplanar = true
  _sculpture_material.uv1_triplanar_sharpness = 4.0
  _sculpture_material.uv1_scale = Vector3(2, 2, 2)
  _sculpture_material.roughness = 1.0
  _sculpture_material.metallic = 0.0

func _build_plinth():
  var plinth = MeshInstance3D.new()
  var box = BoxMesh.new()
  box.size = Vector3(0.9, PLINTH_HEIGHT, PLINTH_DEPTH)
  plinth.mesh = box
  plinth.material_override = _marble_material
  plinth.position = Vector3.ZERO
  plinth.visibility_range_end = 35.0
  plinth.visibility_range_end_margin = 10.0
  plinth.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
  plinth.add_to_group("render_distance")
  add_child(plinth)

  var shelf = MeshInstance3D.new()
  var shelf_box = BoxMesh.new()
  shelf_box.size = Vector3(0.95, SHELF_HEIGHT, PLINTH_DEPTH + 0.05)
  shelf.mesh = shelf_box
  shelf.material_override = _wood_material
  shelf.position = Vector3(0, PLINTH_HEIGHT / 2.0 + SHELF_HEIGHT / 2.0, 0)
  shelf.visibility_range_end = 35.0
  shelf.visibility_range_end_margin = 10.0
  shelf.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
  shelf.add_to_group("render_distance")
  add_child(shelf)

func _build_light():
  _light = SpotLight3D.new()
  _light.position = Vector3(0, 2.5, 3.0)
  _light.light_energy = 0.0
  _light.shadow_enabled = true
  _light.spot_range = 8.0
  _light.spot_angle = 45.0
  _light.spot_attenuation = 2.0
  _light.distance_fade_enabled = true
  _light.add_to_group("managed_light")
  add_child(_light)
  call_deferred("_orient_light")

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

  var normalized = _normalize_mesh(mesh)
  _sculpture_instance.mesh = normalized

  var aabb = normalized.get_aabb()
  _sculpture_instance.position = Vector3(
    0,
    (PLINTH_HEIGHT / 2.0 + SHELF_HEIGHT) - aabb.position.y + 0.01,
    0
  )

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

  visible = true
  emit_signal("loaded")

func _normalize_mesh(mesh: ArrayMesh) -> ArrayMesh:
  if mesh.get_surface_count() == 0:
    return mesh
  var arrays = mesh.surface_get_arrays(0)
  var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  if verts.size() == 0:
    return mesh

  var min_v = verts[0]
  var max_v = verts[0]
  for v in verts:
    min_v = Vector3(minf(min_v.x, v.x), minf(min_v.y, v.y), minf(min_v.z, v.z))
    max_v = Vector3(maxf(max_v.x, v.x), maxf(max_v.y, v.y), maxf(max_v.z, v.z))

  var size = max_v - min_v
  var max_dim = maxf(size.x, maxf(size.y, size.z))
  if max_dim == 0.0:
    return mesh

  var scale_factor = SCULPTURE_SIZE / max_dim
  var center = (min_v + max_v) / 2.0

  var new_verts = PackedVector3Array()
  new_verts.resize(verts.size())
  for i in range(verts.size()):
    new_verts[i] = (verts[i] - center) * scale_factor
  arrays[Mesh.ARRAY_VERTEX] = new_verts

  var new_mesh = ArrayMesh.new()
  new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  return new_mesh

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
    DataManager.request_stl(stl_url)

func init(_title: String, _text: String):
  title = _title
  text = _text

  var data = ExhibitFetcher.get_result(title)
  if data:
    _apply_data(data)
  else:
    ExhibitFetcher.images_complete.connect(_on_data_complete)
    ExhibitFetcher.commons_images_complete.connect(_on_data_complete)
