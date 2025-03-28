extends Node

var thread: Thread

var mutex := Mutex.new()
var semaphore := Semaphore.new()

var should_exit := false
var queue: Array[Callable] = []

# Called when the node enters the scene tree for the first time.
func _ready():
  thread = Thread.new()
  thread.start(_thread_loop)

func _exit_tree() -> void:
  mutex.lock()
  should_exit = true
  mutex.unlock()
  semaphore.post()

  thread.wait_to_finish()

func _thread_loop():
  while true:
    semaphore.wait()
    mutex.lock()
    if should_exit:
        mutex.unlock()
        return
    var task: Callable = queue.pop_front()
    mutex.unlock()
    task.call()

func queue_work(c: Callable):
  mutex.lock()
  queue.push_back(c)
  mutex.unlock()
  semaphore.post()

func get_mipmapped_texture_async(texture: Texture2D, callback: Callable):
  var width = texture.get_width()
  var height = texture.get_height()
  var rid = texture.get_rid()
  var format = RenderingServer.texture_get_format(rid)
  var rd_rid = RenderingServer.texture_get_rd_texture(rid)
  RenderingServer.get_rendering_device().texture_get_data_async(rd_rid, 0, func(array) -> void:
    queue_work(func() -> void:
      var img = Image.create_from_data(width, height, false, format, array)
      img.generate_mipmaps()
      var mipmapped_texture := ImageTexture.create_from_image(img)
      if callback.is_valid():
        callback.call_deferred(mipmapped_texture)
    )
  )

func get_viewport_texture_with_mipmaps(subviewport: SubViewport, callback: Callable):
  await RenderingServer.frame_post_draw
  get_mipmapped_texture_async(subviewport.get_texture(), callback)
