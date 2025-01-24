extends Node

@export var max_cache_size = 5e8
@export var target_cache_size = 5e8

func _exit_tree():
	CacheControl.cull_cache_to_size(max_cache_size, target_cache_size)
