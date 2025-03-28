@tool
extends MeshInstance3D

@export_multiline var text = "[Replace me]"

func _ready() -> void:
  $SubViewport/Control/RichTextLabel.text = text
  if not Engine.is_editor_hint():
    MipmapThread.get_viewport_texture_with_mipmaps($SubViewport, func(texture):
      $Sprite3D.texture = texture
      $SubViewport.queue_free()
    )
