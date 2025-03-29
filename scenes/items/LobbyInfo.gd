@tool
extends MeshInstance3D

@export_multiline var text = "[Replace me]"

func _ready() -> void:
  $SubViewport/Control/RichTextLabel.text = text
  if not Engine.is_editor_hint():
    _generate_mipmaps()
    GlobalMenuEvents.set_language.connect(_generate_mipmaps)
    
func _generate_mipmaps(_lang: String = "") -> void:
  $SubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE
  MipmapThread.get_viewport_texture_with_mipmaps($SubViewport, func(texture):
    $Sprite3D.texture = texture
  )
