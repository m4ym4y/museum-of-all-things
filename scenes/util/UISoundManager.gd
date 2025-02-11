extends Node

@export var button_press_sound: AudioStream
@export var focus_sound: AudioStream
@export var drag_ended_sound: AudioStream

func _on_node_added(node):
	if node is Button:
		node.pressed.connect(_play.bind(button_press_sound))
		node.focus_entered.connect(_play.bind(focus_sound))
	elif node is Slider:
		node.value_changed.connect(_slider_value_changed)
		node.focus_entered.connect(_play.bind(focus_sound))

func _slider_value_changed(_value):
	_play(drag_ended_sound)

func _play(sfx):
	var player = AudioStreamPlayer.new()
	player.stream = sfx
	player.bus = &"Sound"
	add_child(player)
	player.finished.connect(_sound_finished.bind(player))
	player.play()

func _sound_finished(player):
	player.queue_free()

func _traverse_tree(node):
	for c in node.get_children():
		_on_node_added(c)
		_traverse_tree(c)

func _ready() -> void:
	get_tree().create_timer(1.0).timeout.connect(_init_sounds)

func _init_sounds():
	get_tree().node_added.connect(_on_node_added)
	_traverse_tree(get_tree().get_root())
