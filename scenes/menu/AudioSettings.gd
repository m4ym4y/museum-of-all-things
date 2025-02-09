extends VBoxContainer

signal resume

var _audio_ns = "audio"
var global_bus_name: String = "Master"
var global_bus_idx: int
var sound_bus_name: String = "Sound"
var sound_bus_idx: int
var ambience_bus_name: String = "Ambience"
var ambience_bus_idx: int
var music_bus_name: String = "Music"
var music_bus_idx: int
var _loaded_settings = false

func _ready() -> void:
	global_bus_idx = AudioServer.get_bus_index(global_bus_name)
	sound_bus_idx = AudioServer.get_bus_index(sound_bus_name)
	ambience_bus_idx = AudioServer.get_bus_index(ambience_bus_name)
	music_bus_idx = AudioServer.get_bus_index(music_bus_name)

	var settings = SettingsManager.get_settings(_audio_ns)
	_loaded_settings = true
	if settings:
		$VolumeOptions/GlobalVolume.value = settings.global
		$VolumeOptions/SoundVolume.value = settings.sound
		$VolumeOptions/AmbienceVolume.value = settings.ambience
		$VolumeOptions/MusicVolume.value = settings.music

func _create_settings_obj():
	return {
		"global": $VolumeOptions/GlobalVolume.value,
		"sound": $VolumeOptions/SoundVolume.value,
		"ambience": $VolumeOptions/AmbienceVolume.value,
		"music": $VolumeOptions/MusicVolume.value,
	}

func _on_visibility_changed():
	if _loaded_settings and not visible:
		_save_settings()

func _save_settings():
	SettingsManager.save_settings(_audio_ns, _create_settings_obj())

func _on_global_volume_changed(value: float) -> void:
	$VolumeOptions/GlobalValue.text = str(value * 100) + "%"
	_change_volume(global_bus_idx, value)

func _on_sound_volume_changed(value: float) -> void:
	$VolumeOptions/SoundValue.text = str(value * 100) + "%"
	_change_volume(sound_bus_idx, value)

func _on_ambience_volume_changed(value: float) -> void:
	$VolumeOptions/AmbienceValue.text = str(value * 100) + "%"
	_change_volume(ambience_bus_idx, value)

func _on_music_volume_changed(value: float) -> void:
	$VolumeOptions/MusicValue.text = str(value * 100) + "%"
	_change_volume(music_bus_idx, value)

func _change_volume(idx: int, value: float) -> void:
	AudioServer.set_bus_volume_db(idx, linear_to_db(value))

func _on_resume():
	_save_settings()
	emit_signal("resume")
