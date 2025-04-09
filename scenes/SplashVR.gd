extends Node3D

const MAIN_SCENE_PATH = "res://scenes/Main.tscn"

var loading_started := false

func _ready() -> void:
	# Do minimal XR setup. More complete setup will be done in XRRoot.
	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.initialize():
		get_viewport().use_xr = true

func _on_start_timer_timeout() -> void:
	# Give it a second before we start loading so the current environment can get working smoothly.
	ResourceLoader.load_threaded_request(MAIN_SCENE_PATH, "PackedScene")
	loading_started = true

func _process(delta: float) -> void:
	if not loading_started:
		return

	var status = ResourceLoader.load_threaded_get_status(MAIN_SCENE_PATH)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene = ResourceLoader.load_threaded_get(MAIN_SCENE_PATH)
		get_tree().change_scene_to_packed(scene)
		return

	OS.alert("Unable to load main scene")
	loading_started = false
