extends Node

signal loaded_image(url: String, image: Image)
signal loaded_mesh(url: String, mesh: ArrayMesh)

@onready var COMMON_HEADERS = [ "accept: image/png, image/jpeg; charset=utf-8" ]
@onready var _in_flight = {}
@onready var _xr = Util.is_xr()

var TEXTURE_QUEUE = "Textures"
var TEXTURE_FRAME_PACING = 6
var _fs_lock = Mutex.new()
var _texture_load_thread_pool_size = 5
var _texture_load_thread_pool = []
var _parsed_meshes = {}
var _parsed_meshes_lock = Mutex.new()

# Called when the node enters the scene tree for the first time.
func _ready():
  WorkQueue.setup_queue(TEXTURE_QUEUE, TEXTURE_FRAME_PACING)

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
            _parse_stl(item.url, data, item.ctx)
        if Util.is_web():
          RequestSync.request_async(item.url).completed.connect(handle_result)
        else:
          handle_result.call(RequestSync.request(item.url))
      else:
        _parse_stl(item.url, data, item.ctx)

    "parse_stl":
      var mesh = _do_parse_binary_stl(item.data)
      if mesh:
        _parsed_meshes_lock.lock()
        _parsed_meshes[item.url] = mesh
        _parsed_meshes_lock.unlock()
        call_deferred("emit_signal", "loaded_mesh", item.url, mesh, item.ctx)

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

func request_stl(url, ctx=null):
  _parsed_meshes_lock.lock()
  var cached = _parsed_meshes.get(url, null)
  _parsed_meshes_lock.unlock()
  if cached:
    call_deferred("emit_signal", "loaded_mesh", url, cached, ctx)
    return
  WorkQueue.add_item(TEXTURE_QUEUE, {
    "type": "request_stl",
    "url": url,
    "ctx": ctx,
  })

func _parse_stl(url, data, ctx=null):
  WorkQueue.add_item(TEXTURE_QUEUE, {
    "type": "parse_stl",
    "url": url,
    "data": data,
    "ctx": ctx,
  }, null, true)

const STL_TARGET_MAX = 500000

func _do_parse_binary_stl(data: PackedByteArray) -> ArrayMesh:
  if data.size() < 84:
    push_error("STL data too small: %d bytes" % data.size())
    return null

  var num_triangles = data.decode_u32(80)
  var expected_size = 84 + num_triangles * 50
  if data.size() < expected_size:
    push_warning("STL data may be truncated, adjusting triangle count")
    num_triangles = (data.size() - 84) / 50

  if num_triangles == 0:
    push_error("STL has no triangles")
    return null

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

  var mesh = ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  return mesh
