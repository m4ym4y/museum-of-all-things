extends Node3D

func init():
  var slide_tween = create_tween()
  slide_tween.tween_property(
    $MeshInstance3D,
    "position",
    Vector3(0, 13, 0),
    1.0)

  $SlideSound.play()
  slide_tween.set_trans(Tween.TRANS_LINEAR)
  slide_tween.set_ease(Tween.EASE_IN_OUT)
  slide_tween.finished.connect(_on_slide_finished)

func _on_slide_finished():
  queue_free()
