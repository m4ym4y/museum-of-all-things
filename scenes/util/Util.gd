extends Node

func vecToRot(vec):
	if vec.z < -0.1:
		return 0.0
	elif vec.z > 0.1:
		return PI
	elif vec.x > 0.1:
		return 3 * PI / 2
	elif vec.x < -0.1:
		return PI / 2
	return 0.0

func vecToOrientation(grid, vec):
	var vec_basis = Basis.looking_at(vec.normalized())
	return grid.get_orthogonal_index_from_basis(vec_basis)

func gridToWorld(vec):
	return 4 * vec

func coalesce(a, b):
	return a if a else b

func clear_listeners(n, sig_name):
	var list = n.get_signal_connection_list(sig_name)
	for c in list:
		c.signal.disconnect(c.callable)

func is_xr():
	return ProjectSettings.get_setting("xr/openxr/enabled")
