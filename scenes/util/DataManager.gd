extends Node

signal loaded_image(url: String, image: Image)
signal loaded_mesh(url: String, mesh: ArrayMesh)

@onready var COMMON_HEADERS = [ "accept: image/png, image/jpeg; charset=utf-8" ]
@onready var _in_flight = {}
@onready var _xr = Util.is_xr()

var TEXTURE_QUEUE = "Textures"
var TEXTURE_FRAME_PACING = 6
var STL_QUEUE = "STL"
var STL_FRAME_PACING = 1
var _fs_lock = Mutex.new()
var _texture_load_thread_pool_size = 5
var _texture_load_thread_pool = []

class STLParseState extends RefCounted:
  var data: PackedByteArray
  var num_triangles: int
  var vertices: PackedVector3Array

class STLSimplifyState extends RefCounted:
  var in_verts: PackedVector3Array
  var target_count: int
  var url: String
  var target_size: float
  var ctx
  var min_v := Vector3(INF, INF, INF)
  var max_v := Vector3(-INF, -INF, -INF)
  var size_v: Vector3
  var grid_dim: int
  var cell_rep: Dictionary
  var rep_verts: Array
  var f0: Array
  var f1: Array
  var f2: Array
  var out_verts: Array
  var face_normals: Array
  var pos_to_norm: Dictionary
  var out_norms: Array

const STL_CHUNK_SIZE = 5000

# Called when the node enters the scene tree for the first time.
func _ready():
  STL_TARGET_MAX = Util.get_stl_target_max()
  WorkQueue.setup_queue(TEXTURE_QUEUE, TEXTURE_FRAME_PACING)
  WorkQueue.setup_queue(STL_QUEUE, STL_FRAME_PACING)

  if not Util.is_web():
    var cache_dir = CacheControl.cache_dir
    var dir = DirAccess.open(cache_dir)
    if not dir:
      DirAccess.make_dir_recursive_absolute(cache_dir)
      if OS.is_debug_build():
        print("cache directory created at '%s'" + cache_dir)

  if Util.is_using_threads():
    for _i in range(_texture_load_thread_pool_size):
      var thread = Thread.new()
      thread.start(_texture_load_thread_loop)
      _texture_load_thread_pool.append(thread)

func _exit_tree():
  WorkQueue.set_quitting()
  for thread in _texture_load_thread_pool:
    thread.wait_to_finish()

func _texture_load_thread_loop():
  while not WorkQueue.get_quitting():
    _texture_load_item()

func _process(delta: float) -> void:
  if not Util.is_using_threads():
    _texture_load_item()
    _stl_chunk_item()

func _texture_load_item():
  var item = WorkQueue.process_queue(TEXTURE_QUEUE)
  if not item:
    return

  match item.type:
    "request_stl":
      var data = _read_url(item.url)
      if not data:
        var handle_result = func(result):
          if result[0] != OK or result[1] != 200:
            push_error("failed to fetch STL ", result[0], " ", result[1], " ", item.url)
          else:
            data = result[3]
            _write_url(item.url, data)
            _parse_stl(item.url, data, item.target_size, item.ctx)
        if Util.is_web():
          RequestSync.request_async(item.url).completed.connect(handle_result)
        else:
          handle_result.call(RequestSync.request(item.url))
      else:
        _parse_stl(item.url, data, item.target_size, item.ctx)

    "parse_stl":
      if Util.is_using_threads():
        var arrays = _do_parse_binary_stl(item.data)
        if not arrays.is_empty():
          arrays = _normalize_arrays(arrays, item.target_size)
          var mesh = ArrayMesh.new()
          mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
          call_deferred("emit_signal", "loaded_mesh", item.url, mesh, item.ctx)
      else:
        # Web: split decode across frames to avoid blocking the main thread.
        var state = STLParseState.new()
        state.data = item.data
        if state.data.size() < 84:
          push_error("STL data too small: %d bytes" % state.data.size())
          return
        state.num_triangles = state.data.decode_u32(80)
        var expected_size = 84 + state.num_triangles * 50
        if state.data.size() < expected_size:
          push_warning("STL data may be truncated, adjusting triangle count")
          state.num_triangles = (state.data.size() - 84) / 50
        if state.num_triangles == 0:
          push_error("STL has no triangles")
          return
        state.vertices = PackedVector3Array()
        WorkQueue.add_item(STL_QUEUE, {
          "type": "parse_stl_chunk",
          "state": state,
          "url": item.url,
          "target_size": item.target_size,
          "ctx": item.ctx,
          "chunk_start": 0,
        })

    "request":
        var data = _read_url(item.url)

        if data:
          _load_image(item.url, data, item.ctx)
        else:
          var request_url = item.url
          request_url += ('&' if '?' in request_url else '?') + "origin=*"

          var handle_result = func(result):
            if result[0] == OK and result[1] == 429:
              # Requeue images if we have been rate limited.
              # See: https://www.mediawiki.org/wiki/Wikimedia_APIs/Rate_limits
              var delay = 1000
              for header in result[2]:
                if header.to_lower().begins_with("retry-after:"):
                  var delay_seconds = int(header.get_slice(":", 1).strip_edges())
                  if delay_seconds > 0:
                    delay = delay_seconds * 1000
                  break
              push_warning("rate limited, requeuing image in %dms: %s" % [delay, item.url])
              await Util.delay_msec_async(delay)
              request_image(item.url, item.ctx)
            elif result[0] != OK or result[1] != 200:
              push_error("failed to fetch image ", result[0], " ", result[1], " ", item.url)
            else:
              data = result[3]
              _write_url(item.url, data)
              _load_image(item.url, data, item.ctx)

          if Util.is_web():
            RequestSync.request_async(request_url, COMMON_HEADERS).completed.connect(handle_result)
          else:
            handle_result.call(RequestSync.request(request_url, COMMON_HEADERS))

    "load":
      var data = item.data

      var fmt = _detect_image_type(data)
      var image = Image.new()
      if fmt == "PNG":
        image.load_png_from_buffer(data)
      elif fmt == "JPEG":
        image.load_jpg_from_buffer(data)
      elif fmt == "SVG":
        image.load_svg_from_buffer(data)
      elif fmt == "WebP":
        image.load_webp_from_buffer(data)
      else:
        print("Unknown image type: ", item.url)
        return

      if image.get_width() == 0:
        return

      _generate_mipmaps(item.url, image, item.ctx)

    "generate_mipmaps":
      var image = item.image
      image.generate_mipmaps()
      _create_and_emit_texture(item.url, image, item.ctx)

    "create_and_emit_texture":
      var texture = ImageTexture.create_from_image(item.image)
      _emit_image(item.url, texture, item.ctx)

func _stl_chunk_item():
  var item = WorkQueue.process_queue(STL_QUEUE)
  if not item:
    return
  match item.type:

    "parse_stl_chunk":
      var state: STLParseState = item.state
      var chunk_start: int = item.chunk_start
      var chunk_end: int = mini(chunk_start + STL_CHUNK_SIZE, state.num_triangles)
      var chunk_verts = PackedVector3Array()
      chunk_verts.resize((chunk_end - chunk_start) * 3)
      var data: PackedByteArray = state.data
      for i in range(chunk_start, chunk_end):
        var byte_offset = 84 + i * 50
        var local_i = i - chunk_start
        chunk_verts[local_i * 3]     = Vector3(data.decode_float(byte_offset + 12),  data.decode_float(byte_offset + 20), -data.decode_float(byte_offset + 16))
        chunk_verts[local_i * 3 + 1] = Vector3(data.decode_float(byte_offset + 36),  data.decode_float(byte_offset + 44), -data.decode_float(byte_offset + 40))
        chunk_verts[local_i * 3 + 2] = Vector3(data.decode_float(byte_offset + 24),  data.decode_float(byte_offset + 32), -data.decode_float(byte_offset + 28))
      state.vertices.append_array(chunk_verts)
      if chunk_end < state.num_triangles:
        WorkQueue.add_item(STL_QUEUE, {"type": "parse_stl_chunk", "state": state,
            "url": item.url, "target_size": item.target_size, "ctx": item.ctx, "chunk_start": chunk_end})
      else:
        var ss = STLSimplifyState.new()
        ss.in_verts = state.vertices
        ss.target_count = STL_TARGET_MAX
        ss.url = item.url; ss.target_size = item.target_size; ss.ctx = item.ctx
        ss.rep_verts = []; ss.f0 = []; ss.f1 = []; ss.f2 = []
        ss.out_verts = []; ss.face_normals = []; ss.out_norms = []
        WorkQueue.add_item(STL_QUEUE, {"type": "simplify_bounds_chunk", "state": ss, "chunk_start": 0})

    "simplify_bounds_chunk":
      var ss: STLSimplifyState = item.state
      var face_count = ss.in_verts.size() / 3
      var chunk_end = mini(item.chunk_start + STL_CHUNK_SIZE, face_count)
      var min_v = ss.min_v; var max_v = ss.max_v
      for i in range(item.chunk_start, chunk_end):
        for j in 3:
          var v = ss.in_verts[i * 3 + j]
          min_v = Vector3(minf(min_v.x, v.x), minf(min_v.y, v.y), minf(min_v.z, v.z))
          max_v = Vector3(maxf(max_v.x, v.x), maxf(max_v.y, v.y), maxf(max_v.z, v.z))
      ss.min_v = min_v; ss.max_v = max_v
      if chunk_end < face_count:
        WorkQueue.add_item(STL_QUEUE, {"type": "simplify_bounds_chunk", "state": ss, "chunk_start": chunk_end})
      else:
        var s = ss.max_v - ss.min_v
        if s.x == 0.0: s.x = 1.0
        if s.y == 0.0: s.y = 1.0
        if s.z == 0.0: s.z = 1.0
        ss.size_v = s
        ss.grid_dim = maxi(2, ceili(pow(float(ss.target_count) * 1.5, 1.0 / 3.0)))
        ss.cell_rep = {}
        WorkQueue.add_item(STL_QUEUE, {"type": "simplify_assign_chunk", "state": ss, "chunk_start": 0})

    "simplify_assign_chunk":
      var ss: STLSimplifyState = item.state
      var face_count = ss.in_verts.size() / 3
      var chunk_end = mini(item.chunk_start + STL_CHUNK_SIZE, face_count)
      var min_v = ss.min_v; var size_v = ss.size_v; var gd = ss.grid_dim
      var cell_rep = ss.cell_rep; var rep_verts = ss.rep_verts
      var f0 = ss.f0; var f1 = ss.f1; var f2 = ss.f2
      for i in range(item.chunk_start, chunk_end):
        for slot in 3:
          var v = ss.in_verts[i * 3 + slot]
          var cx = clampi(int((v.x - min_v.x) / size_v.x * gd), 0, gd - 1)
          var cy = clampi(int((v.y - min_v.y) / size_v.y * gd), 0, gd - 1)
          var cz = clampi(int((v.z - min_v.z) / size_v.z * gd), 0, gd - 1)
          var key = cx * gd * gd + cy * gd + cz
          if not cell_rep.has(key):
            cell_rep[key] = rep_verts.size()
            rep_verts.push_back(v)
          if slot == 0: f0.push_back(cell_rep[key])
          elif slot == 1: f1.push_back(cell_rep[key])
          else: f2.push_back(cell_rep[key])
      if chunk_end < face_count:
        WorkQueue.add_item(STL_QUEUE, {"type": "simplify_assign_chunk", "state": ss, "chunk_start": chunk_end})
      else:
        WorkQueue.add_item(STL_QUEUE, {"type": "simplify_build_chunk", "state": ss, "chunk_start": 0})

    "simplify_build_chunk":
      var ss: STLSimplifyState = item.state
      var face_count = ss.in_verts.size() / 3
      var chunk_end = mini(item.chunk_start + STL_CHUNK_SIZE, face_count)
      var rep_verts = ss.rep_verts; var f0 = ss.f0; var f1 = ss.f1; var f2 = ss.f2
      var out_verts = ss.out_verts; var face_normals = ss.face_normals
      for i in range(item.chunk_start, chunk_end):
        var a = f0[i]; var b = f1[i]; var c = f2[i]
        if a == b or b == c or a == c: continue
        var p0 = rep_verts[a]; var p1 = rep_verts[b]; var p2 = rep_verts[c]
        var n = (p1 - p0).cross(p2 - p0)
        if n.length_squared() < 1e-12: continue
        out_verts.push_back(p0); out_verts.push_back(p1); out_verts.push_back(p2)
        face_normals.push_back(n)
      if chunk_end < face_count:
        WorkQueue.add_item(STL_QUEUE, {"type": "simplify_build_chunk", "state": ss, "chunk_start": chunk_end})
      else:
        ss.pos_to_norm = {}
        WorkQueue.add_item(STL_QUEUE, {"type": "simplify_norm_accum_chunk", "state": ss, "chunk_start": 0})

    "simplify_norm_accum_chunk":
      var ss: STLSimplifyState = item.state
      var tri_count = ss.face_normals.size()
      var chunk_end = mini(item.chunk_start + STL_CHUNK_SIZE, tri_count)
      var pos_to_norm = ss.pos_to_norm; var out_verts = ss.out_verts; var face_normals = ss.face_normals
      for i in range(item.chunk_start, chunk_end):
        var n = face_normals[i]
        for j in 3:
          var p = out_verts[i * 3 + j]
          if pos_to_norm.has(p): pos_to_norm[p] += n
          else: pos_to_norm[p] = n
      if chunk_end < tri_count:
        WorkQueue.add_item(STL_QUEUE, {"type": "simplify_norm_accum_chunk", "state": ss, "chunk_start": chunk_end})
      else:
        WorkQueue.add_item(STL_QUEUE, {"type": "simplify_norm_apply_chunk", "state": ss, "chunk_start": 0})

    "simplify_norm_apply_chunk":
      var ss: STLSimplifyState = item.state
      var total = ss.out_verts.size()
      var chunk_end = mini(item.chunk_start + STL_CHUNK_SIZE * 3, total)
      var pos_to_norm = ss.pos_to_norm; var out_verts = ss.out_verts; var out_norms = ss.out_norms
      for i in range(item.chunk_start, chunk_end):
        out_norms.push_back(-(pos_to_norm[out_verts[i]] as Vector3).normalized())
      if chunk_end < total:
        WorkQueue.add_item(STL_QUEUE, {"type": "simplify_norm_apply_chunk", "state": ss, "chunk_start": chunk_end})
      else:
        if ss.out_verts.is_empty():
          push_error("STL simplification produced no triangles: %s" % ss.url)
          return
        print("STL: %d → %d triangles" % [ss.in_verts.size() / 3, ss.out_verts.size() / 3])
        var arrays = []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(ss.out_verts)
        arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(ss.out_norms)
        arrays = _normalize_arrays(arrays, ss.target_size)
        var mesh = ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        call_deferred("emit_signal", "loaded_mesh", ss.url, mesh, ss.ctx)

func _get_hash(input: String) -> String:
  var context = HashingContext.new()
  context.start(HashingContext.HASH_SHA256)
  context.update(input.to_utf8_buffer())
  var hash_result = context.finish()
  return hash_result.hex_encode()

func _detect_image_type(data: PackedByteArray) -> String:
  if data.size() < 8:
    return "Unknown"  # Insufficient data to determine type

  # Convert to hexadecimal strings for easy comparison
  var header = data.slice(0, 8)
  var hex_header = ""
  for byte in header:
    hex_header += ("%02x" % byte).to_lower()

  # Check PNG signature
  if hex_header.begins_with("89504e470d0a1a0a"):
    return "PNG"

  # Check JPEG signature
  if hex_header.begins_with("ffd8ff"):
    return "JPEG"

  # Check WebP signature (RIFF and WEBP)
  if hex_header.begins_with("52494646"):  # "RIFF"
    if data.size() >= 12:
      var riff_type = data.slice(8, 12).get_string_from_ascii()
      if riff_type == "WEBP":
        return "WebP"

  # Check SVG (look for '<?xml' or '<svg')
  if data.size() >= 5:
    var xml_start = data.slice(0, 5).get_string_from_utf8()
    if xml_start.begins_with("<?xml") or xml_start.begins_with("<svg"):
      return "SVG"
  return "Unknown"

func _write_url(url: String, data: PackedByteArray) -> void:
  if Util.is_web():
    return
  _fs_lock.lock()
  var filename = _get_hash(url)
  var f = FileAccess.open(CacheControl.cache_dir + filename, FileAccess.WRITE)
  if f:
    f.store_buffer(data)
    f.close()
  else:
    push_error("failed to write file ", url)
  _fs_lock.unlock()

func _read_url(url: String):
  if Util.is_web():
    return null
  _fs_lock.lock()
  var filename = _get_hash(url)
  var file_path = CacheControl.cache_dir + filename
  var f = FileAccess.open(file_path, FileAccess.READ)
  if f:
    var data = f.get_buffer(f.get_length())
    f.close()
    _fs_lock.unlock()
    return data
  else:
    _fs_lock.unlock()
    return null

func _url_exists(url: String):
  if Util.is_web():
    return false
  _fs_lock.lock()
  var filename = _get_hash(url)
  var res = FileAccess.file_exists(CacheControl.cache_dir + filename)
  _fs_lock.unlock()
  return res

func load_json_data(url: String):
  var data = _read_url(url)
  if data:
    var json = data.get_string_from_utf8()
    return JSON.parse_string(json)
  else:
    return null

func save_json_data(url: String, json: Dictionary):
  if Util.is_web():
    return
  var data = JSON.stringify(json).to_utf8_buffer()
  _write_url(url, data)

func _emit_image(url, texture, ctx):
  if texture == null:
    return
  call_deferred("emit_signal", "loaded_image", url, texture, ctx)

func request_image(url, ctx=null):
  WorkQueue.add_item(TEXTURE_QUEUE, {
    "type": "request",
    "url": url,
    "ctx": ctx
  })

func _load_image(url, data, ctx=null):
  WorkQueue.add_item(TEXTURE_QUEUE, {
    "type": "load",
    "url": url,
    "data": data,
    "ctx": ctx,
  }, null, true)

func _generate_mipmaps(url, image, ctx=null):
  WorkQueue.add_item(TEXTURE_QUEUE, {
    "type": "generate_mipmaps",
    "url": url,
    "image": image,
    "ctx": ctx,
  }, null, true)

func _create_and_emit_texture(url, image, ctx=null):
  WorkQueue.add_item(TEXTURE_QUEUE, {
    "type": "create_and_emit_texture",
    "url": url,
    "image": image,
    "ctx": ctx,
  }, null, true)

func request_stl(url, target_size: float, ctx=null):
  WorkQueue.add_item(TEXTURE_QUEUE, {
    "type": "request_stl",
    "url": url,
    "target_size": target_size,
    "ctx": ctx,
  })

func _parse_stl(url, data, target_size: float, ctx=null):
  WorkQueue.add_item(TEXTURE_QUEUE, {
    "type": "parse_stl",
    "url": url,
    "data": data,
    "target_size": target_size,
    "ctx": ctx,
  }, null, true)

func _normalize_arrays(arrays: Array, target_size: float) -> Array:
  var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
  if verts.size() == 0:
    return arrays

  var min_v = verts[0]
  var max_v = verts[0]
  for v in verts:
    min_v = Vector3(minf(min_v.x, v.x), minf(min_v.y, v.y), minf(min_v.z, v.z))
    max_v = Vector3(maxf(max_v.x, v.x), maxf(max_v.y, v.y), maxf(max_v.z, v.z))

  var size = max_v - min_v
  var max_dim = maxf(size.x, maxf(size.y, size.z))
  if max_dim == 0.0:
    return arrays

  var scale_factor = target_size / max_dim
  var center = (min_v + max_v) / 2.0
  var new_verts = PackedVector3Array()
  new_verts.resize(verts.size())
  for i in range(verts.size()):
    new_verts[i] = (verts[i] - center) * scale_factor
  arrays[Mesh.ARRAY_VERTEX] = new_verts
  return arrays

var STL_TARGET_MAX: int

func _do_parse_binary_stl(data: PackedByteArray) -> Array:
  if data.size() < 84:
    push_error("STL data too small: %d bytes" % data.size())
    return []

  var num_triangles = data.decode_u32(80)
  var expected_size = 84 + num_triangles * 50
  if data.size() < expected_size:
    push_warning("STL data may be truncated, adjusting triangle count")
    num_triangles = (data.size() - 84) / 50

  if num_triangles == 0:
    push_error("STL has no triangles")
    return []

  var vertices = PackedVector3Array()
  vertices.resize(num_triangles * 3)

  for i in num_triangles:
    var byte_offset = 84 + i * 50
    # STL uses Z-up; convert to Godot Y-up: (x, y, z) → (x, z, -y)
    # The reflection (-y) flips chirality, so swap v1/v2 to restore outward winding.
    vertices[i * 3]     = Vector3(data.decode_float(byte_offset + 12),  data.decode_float(byte_offset + 20), -data.decode_float(byte_offset + 16))
    vertices[i * 3 + 1] = Vector3(data.decode_float(byte_offset + 36),  data.decode_float(byte_offset + 44), -data.decode_float(byte_offset + 40))
    vertices[i * 3 + 2] = Vector3(data.decode_float(byte_offset + 24),  data.decode_float(byte_offset + 32), -data.decode_float(byte_offset + 28))

  var input_tri_count = vertices.size() / 3
  var simplified = MeshSimplifier.simplify(vertices, STL_TARGET_MAX)
  vertices = simplified[0]
  var normals = simplified[1]
  print("STL: %d → %d triangles" % [input_tri_count, vertices.size() / 3])

  var arrays = []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_NORMAL] = normals
  return arrays
