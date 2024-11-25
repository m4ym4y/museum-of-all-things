extends Area3D

signal direction_changed(direction: String)

var point_a: Vector3
var point_b: Vector3
var player_velocity: Vector3
var previous_direction: Vector3
var player

func init(entry: Vector3, exit: Vector3):
	point_a = entry
	point_b = exit
	previous_direction = Vector3.ZERO
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		player = body

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		player = null

func _process(_delta: float) -> void:
	if player:
		var to_a = (point_a - global_transform.origin).normalized()
		var to_b = (point_b - global_transform.origin).normalized()

		var v = player.velocity
		var dot_to_a = v.dot(to_a)
		var dot_to_b = v.dot(to_b)

		var current_direction: Vector3
		if dot_to_a > 0 and dot_to_a > dot_to_b:
			current_direction = to_a
		elif dot_to_b > 0 and dot_to_b > dot_to_a:
			current_direction = to_b
		else:
			return

		if current_direction != previous_direction:
			var result = "entry" if current_direction == to_a else "exit"
			print("direction change to ", result)
			emit_signal("direction_changed", result)
			previous_direction = current_direction

