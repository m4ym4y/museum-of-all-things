extends Node

# Vertex clustering decimation.
# Divides the mesh bounding box into a voxel grid; vertices in the same cell
# collapse to a single point. Degenerate triangles (two or more vertices in
# the same cell) are discarded. O(n) — handles large meshes comfortably.

func simplify(in_verts: PackedVector3Array, target_count: int) -> Array:
  if in_verts.size() < 3:
    return [in_verts, PackedVector3Array()]

  var min_v = in_verts[0]
  var max_v = in_verts[0]
  for v in in_verts:
    min_v = Vector3(minf(min_v.x, v.x), minf(min_v.y, v.y), minf(min_v.z, v.z))
    max_v = Vector3(maxf(max_v.x, v.x), maxf(max_v.y, v.y), maxf(max_v.z, v.z))

  var size = max_v - min_v
  if size.x == 0.0: size.x = 1.0
  if size.y == 0.0: size.y = 1.0
  if size.z == 0.0: size.z = 1.0

  # Grid resolution tuned so the expected surviving triangle count ≈ target_count.
  # Each surviving triangle needs 3 distinct cells, and about half the triangles
  # survive clustering, so grid cells ≈ target_count * 1.5.
  var grid_dim = maxi(2, ceili(pow(float(target_count) * 1.5, 1.0 / 3.0)))

  var cell_rep := {}     # cell_key -> index in rep_verts
  var rep_verts := PackedVector3Array()

  var face_count = in_verts.size() / 3
  var f0 := PackedInt32Array(); f0.resize(face_count)
  var f1 := PackedInt32Array(); f1.resize(face_count)
  var f2 := PackedInt32Array(); f2.resize(face_count)

  for i in face_count:
    f0[i] = _cell_index(in_verts[i * 3],     min_v, size, grid_dim, cell_rep, rep_verts)
    f1[i] = _cell_index(in_verts[i * 3 + 1], min_v, size, grid_dim, cell_rep, rep_verts)
    f2[i] = _cell_index(in_verts[i * 3 + 2], min_v, size, grid_dim, cell_rep, rep_verts)

  var out_verts := PackedVector3Array()
  var face_normals := PackedVector3Array()

  for i in face_count:
    var a = f0[i]; var b = f1[i]; var c = f2[i]
    if a == b or b == c or a == c:
      continue
    var p0: Vector3 = rep_verts[a]
    var p1: Vector3 = rep_verts[b]
    var p2: Vector3 = rep_verts[c]
    var n = (p1 - p0).cross(p2 - p0)
    if n.length_squared() < 1e-12:
      continue
    out_verts.append(p0)
    out_verts.append(p1)
    out_verts.append(p2)
    face_normals.append(n)

  # Smooth normals: accumulate face normals at each shared position.
  # Clustering guarantees that vertices in the same cell have identical positions,
  # so Vector3 equality is exact and safe to use as a dictionary key.
  var pos_to_norm := {}
  var tri_count = face_normals.size()
  for i in tri_count:
    var n = face_normals[i]
    for j in 3:
      var p = out_verts[i * 3 + j]
      if pos_to_norm.has(p):
        pos_to_norm[p] += n
      else:
        pos_to_norm[p] = n

  var out_norms := PackedVector3Array()
  out_norms.resize(out_verts.size())
  for i in out_verts.size():
    out_norms[i] = -pos_to_norm[out_verts[i]].normalized()

  return [out_verts, out_norms]

func _cell_index(v: Vector3, min_v: Vector3, size: Vector3, grid_dim: int,
                 cell_rep: Dictionary, rep_verts: PackedVector3Array) -> int:
  var cx = clampi(int((v.x - min_v.x) / size.x * grid_dim), 0, grid_dim - 1)
  var cy = clampi(int((v.y - min_v.y) / size.y * grid_dim), 0, grid_dim - 1)
  var cz = clampi(int((v.z - min_v.z) / size.z * grid_dim), 0, grid_dim - 1)
  var key = cx * grid_dim * grid_dim + cy * grid_dim + cz
  if not cell_rep.has(key):
    cell_rep[key] = rep_verts.size()
    rep_verts.append(v)
  return cell_rep[key]
