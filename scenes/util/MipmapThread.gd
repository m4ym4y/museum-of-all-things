extends Node

var MIPMAP_QUEUE = "MipmapThread"
var MIPMAP_FRAME_PACING = 6

var thread: Thread

func _ready():
  WorkQueue.setup_queue(MIPMAP_QUEUE, MIPMAP_FRAME_PACING)

  if Util.is_using_threads():
    thread = Thread.new()
    thread.start(_thread_loop)

func _exit_tree() -> void:
  WorkQueue.set_quitting()
  if thread:
    thread.wait_to_finish()

func _thread_loop():
  while not WorkQueue.get_quitting():
    _mipmap_process_item()

func _process(delta: float) -> void:
  if not Util.is_using_threads():
    _mipmap_process_item()

func _mipmap_process_item():
  var item = WorkQueue.process_queue(MIPMAP_QUEUE)
  if not item:
    return

  match item.type:
    "get_texture_data":
      # This item only happens on the compatibility renderer.
      var image = item.texture.get_image()
      _generate_mipmaps(image, item.callback)

    "create_image":
      # This item only happens on RD renderers.
      var image = Image.create_from_data(item.width, item.height, false, item.format, item.data)
      _generate_mipmaps(image, item.callback)

    "generate_mipmaps":
      var image = item.image
      image.generate_mipmaps()
      _create_and_emit_texture(image, item.callback)

    "create_and_emit_texture":
      var texture = ImageTexture.create_from_image(item.image)
      item.callback.call_deferred(texture)

func _get_texture_data_rd(texture: Texture2D, callback: Callable):
  var width = texture.get_width()
  var height = texture.get_height()
  var rid = texture.get_rid()
  var format = RenderingServer.texture_get_format(rid)
  var rd_rid = RenderingServer.texture_get_rd_texture(rid)
  RenderingServer.get_rendering_device().texture_get_data_async(rd_rid, 0, func(array) -> void:
    _create_image(width, height, format, array, callback)
  )

func get_viewport_texture_with_mipmaps(subviewport: SubViewport, callback: Callable):
  await RenderingServer.frame_post_draw
  if Util.is_compatibility_renderer():
    WorkQueue.add_item(MIPMAP_QUEUE, {
      "type": "get_texture_data",
      "texture": subviewport.get_texture(),
      "callback": callback,
    })
  else:
    _get_texture_data_rd(subviewport.get_texture(), callback)

func _create_image(width, height, format, data, callback) -> void:
  WorkQueue.add_item(MIPMAP_QUEUE, {
    "type": "create_image",
    "width": width,
    "height": height,
    "format": format,
    "data": data,
    "callback": callback,
  })

func _generate_mipmaps(image, callback) -> void:
  WorkQueue.add_item(MIPMAP_QUEUE, {
    "type": "generate_mipmaps",
    "image": image,
    "callback": callback,
  }, null, true)

func _create_and_emit_texture(image, callback) -> void:
  WorkQueue.add_item(MIPMAP_QUEUE, {
    "type": "create_and_emit_texture",
    "image": image,
    "callback": callback,
  }, null, true)
