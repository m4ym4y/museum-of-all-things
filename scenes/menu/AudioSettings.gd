extends VBoxContainer

signal resume

var global_bus_name: String = "Master"
var global_bus_idx: int
var sound_bus_name: String = "Sound"
var sound_bus_idx: int
var ambience_bus_name: String = "Ambience"
var ambience_bus_idx: int

func _ready() -> void:
	global_bus_idx = AudioServer.get_bus_index(global_bus_name)
	sound_bus_idx = AudioServer.get_bus_index(sound_bus_name)
	ambience_bus_idx = AudioServer.get_bus_index(ambience_bus_name)

func _on_global_volume_changed(value: float) -> void:
	$VolumeOptions/GlobalValue.text = str(value * 100) + "%"
	_change_volume(global_bus_idx, value)

func _on_sound_volume_changed(value: float) -> void:
	$VolumeOptions/SoundValue.text = str(value * 100) + "%"
	_change_volume(sound_bus_idx, value)

func _on_ambience_volume_changed(value: float) -> void:
	$VolumeOptions/AmbienceValue.text = str(value * 100) + "%"
	_change_volume(ambience_bus_idx, value)

func _change_volume(idx: int, value: float) -> void:
	AudioServer.set_bus_volume_db(
		idx,
		linear_to_db(value)
	)

func _on_resume():
	emit_signal("resume")
