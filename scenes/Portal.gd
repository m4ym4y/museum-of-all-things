"""
  Asset: Godot Simple Portal System
  File: portal.gd
  Description: A simple portal system for viewport-based portals in Godot 4.
  Instructions: For detailed documentation, see the README or visit: https://github.com/Donitzo/godot-simple-portal-system
  Repository: https://github.com/Donitzo/godot-simple-portal-system
  License: CC0 License
"""

extends MeshInstance3D
class_name Portal
## The portal represents a single portal mesh in a pair of portals.

## The delay between the main viewport changing size and the portal viewport resizing.
const _RESIZE_THROTTLE_SECONDS:float = 0.1

## The minimum camera near clipping distance.
const _EXIT_CAMERA_NEAR_MIN:float = 0.01

## The portal mesh's local bounding box.
@onready var _mesh_aabb:AABB = mesh.get_aabb()

## The vertical resolution of the portal viewport which covers the entire screen not just the portal mesh. Use 0 to use the real resolution.
@export var vertical_viewport_resolution:int = 512

## Disable viewport distance. Portals further away than this won't have their viewports rendered.
@export var disable_viewport_distance:float = 11
## Whether to destroy the disabled viewport to save texture memory. Useful when you have a lot of portals. The viewport is re/-created when within disable_viewport_distance and visible.
@export var destroy_disabled_viewport:bool = true

## The maximum fade-out distance.
@export var fade_out_distance_max:float = 10
## The minimum fade-out distance.
@export var fade_out_distance_min:float = 8
## The fade-out color.
@export var fade_out_color:Color = Color.WHITE

## The scale of the exit side of the portal. < 1 means the exit is smaller than the entrance.
@export var exit_scale:float = 1.0
## A value subtracted from the exit camera near clipping plane. Useful for handling clipping issues.
@export var exit_near_subtract:float = 0.05

## The main camera. Leave unset to use the default 3D camera.
@export var main_camera:Camera3D

## An environment set for the exit camera. Leave unset to use the default environment.
@export var exit_environment:Environment

## The exit portal. Leave unset to use this portal as an exit only.
@export var exit_portal:Portal

var _area: Area3D
var _bodies_inside = []

# The viewport rendering the portal surface
var _viewport:SubViewport

# The exit camera copies the main camera's position relative to the exit portal
var _exit_camera:Camera3D

# The number of seconds until the viewport updates its size
var _seconds_until_resize:float

func _ready() -> void:
  if not is_inside_tree():
    push_error("The portal \"%s\" is not inside a SceneTree." % name)

  # An exit-free portal does not need to do anything
  if exit_portal == null:
    visible = false
    set_process(false)
    return

  if not exit_portal.is_inside_tree() or exit_portal.get_tree() != get_tree():
    push_error("The exit_portal \"%s\" of \"%s\" is not inside the same SceneTree." % [exit_portal.name, name])

  # Non-uniform parent scaling can introduce skew which isn't compensated for
  if get_parent() != null:
    var parent_scale:Vector3 = get_parent().global_transform.basis.get_scale()
    if abs(parent_scale.x - parent_scale.y) > 0.01 or abs(parent_scale.x - parent_scale.z) > 0.01:
      push_warning("The parent of \"%s\" is not uniformly scaled. The portal will not work correctly." % name)

  # The portals should be updated last so the main camera has its final position
  process_priority = 1000

  # Used in raycasting
  add_to_group("portals")

  # Get the main camera
  if main_camera == null:
    main_camera = get_viewport().get_camera_3d()

  # The portal shader renders the viewport on-top of the portal mesh in screen-space
  material_override = ShaderMaterial.new()
  material_override.shader = preload("res://shaders/portal.gdshader")
  material_override.set_shader_parameter("fade_out_distance_max", fade_out_distance_max)
  material_override.set_shader_parameter("fade_out_distance_min", fade_out_distance_min)
  material_override.set_shader_parameter("fade_out_color", fade_out_color)

  # Create the viewport when _ready if it's not destroyed when disabled.
  # This may potentially get rid of the initial lag when the viewport is first created at the cost of texture memory.
  if not destroy_disabled_viewport:
    _create_viewport()

  get_viewport().connect("size_changed", _handle_resize)

  _setup_collision_detection()

func _setup_collision_detection():
    # Get the existing Area3D node called "PortalTeleport"
  _area = $PortalTeleport  # Adjust the path if "PortalTeleport" is not a direct child
  if _area == null:
      push_error("PortalTeleport Area3D node not found as a child of the portal.")
      return

  # Connect the body_entered and body_exited signals
  _area.body_entered.connect(_on_body_entered)
  _area.body_exited.connect(_on_body_exited)

func _on_body_entered(body) -> void:
  if body.is_in_group("Player"):
    # Add the body to the list of bodies inside the portal area
    _bodies_inside.append(body)
    # Attempt to teleport the body
    _attempt_teleport(body)

func _on_body_exited(body) -> void:
  if body.is_in_group("Player"):
    if body in _bodies_inside:
      _bodies_inside.erase(body)

func _attempt_teleport(body:PhysicsBody3D) -> void:
# Check if the body is moving towards the portal
  var body_velocity = body.velocity
  var portal_normal = -global_transform.basis.z.normalized()
  var relative_velocity = body_velocity.normalized().dot(portal_normal)

  if relative_velocity > 0:
    # The body is moving towards the portal
    if exit_portal != null:
      # Transform the body's global transform to the exit portal
      var new_transform = real_to_exit_transform(body.global_transform)
      body.global_transform = new_transform

      # Transform the body's velocity to the exit portal
      var new_velocity = real_to_exit_direction(body.velocity)
      body.velocity = new_velocity

func _handle_resize() -> void:
  _seconds_until_resize = _RESIZE_THROTTLE_SECONDS

func _create_viewport() -> void:
  # Create the viewport for the portal surface
  _viewport = SubViewport.new()
  _viewport.name = "Viewport"
  _viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
  add_child(_viewport)
  material_override.set_shader_parameter("albedo", _viewport.get_texture())

  # Create the exit camera which renders the portal surface for the viewport
  _exit_camera = Camera3D.new()
  _exit_camera.name = "Camera"
  _exit_camera.environment = exit_environment
  _viewport.add_child(_exit_camera)

  # Resize the viewport on the next _process
  _seconds_until_resize = 0

func _process(delta:float) -> void:
  # Disable the viewport if the portal is further away than disable_viewport_distance or if the portal is invisible in the scene tree
  var disable_viewport:bool = not is_visible_in_tree() or\
    main_camera.global_position.distance_squared_to(global_position) > disable_viewport_distance * disable_viewport_distance

  # Enable or disable 3D rendering for the viewport (if it exists)
  if _viewport != null:
    _viewport.disable_3d = disable_viewport

  if disable_viewport:
    # Destroy the disabled viewport to save memory
    if _viewport != null and destroy_disabled_viewport:
      material_override.set_shader_parameter("albedo", null)
      _viewport.queue_free()
      _viewport = null

    # Ensure the portal can re-size the second it is enabled again
    if not is_nan(_seconds_until_resize):
      _seconds_until_resize = 0

    # Don't process the rest if the viewport is disabled
    return

  # Re/-Create viewport
  if _viewport == null:
    _create_viewport()

  # Throttle the viewport resizing for better performance
  if not is_nan(_seconds_until_resize):
    _seconds_until_resize -= delta
    if _seconds_until_resize <= 0:
      _seconds_until_resize = NAN

      var viewport_size:Vector2i = get_viewport().size
      if vertical_viewport_resolution == 0:
        # Resize the viewport to the main viewport size
        _viewport.size = viewport_size
      else:
        # Resize the viewport to the fixed height vertical_viewport_resolution and dynamic width
        var aspect_ratio:float = float(viewport_size.x) / viewport_size.y
        _viewport.size = Vector2i(int(vertical_viewport_resolution * aspect_ratio + 0.5), vertical_viewport_resolution)

  # Move the exit camera relative to the exit portal based on the main camera's position relative to the entrance portal
  _exit_camera.global_transform = real_to_exit_transform(main_camera.global_transform)

  # Get the four X, Y corners of the scaled entrance portal bounding box clamped to Z=0 (portal surface) relative to the exit portal.
  # The entrance portal bounding box is used since the entrance portal mesh does not need to match the exit portal mesh.
  var corner_1:Vector3 = exit_portal.to_global(Vector3(_mesh_aabb.position.x, _mesh_aabb.position.y, 0) * exit_scale)
  var corner_2:Vector3 = exit_portal.to_global(Vector3(_mesh_aabb.position.x + _mesh_aabb.size.x, _mesh_aabb.position.y, 0) * exit_scale)
  var corner_3:Vector3 = exit_portal.to_global(Vector3(_mesh_aabb.position.x + _mesh_aabb.size.x, _mesh_aabb.position.y + _mesh_aabb.size.y, 0) * exit_scale)
  var corner_4:Vector3 = exit_portal.to_global(Vector3(_mesh_aabb.position.x, _mesh_aabb.position.y + _mesh_aabb.size.y, 0) * exit_scale)

  # Calculate the distance along the exit camera forward vector at which each of the portal corners projects
  var camera_forward:Vector3 = -_exit_camera.global_transform.basis.z.normalized()

  var d_1:float = (corner_1 - _exit_camera.global_position).dot(camera_forward)
  var d_2:float = (corner_2 - _exit_camera.global_position).dot(camera_forward)
  var d_3:float = (corner_3 - _exit_camera.global_position).dot(camera_forward)
  var d_4:float = (corner_4 - _exit_camera.global_position).dot(camera_forward)

  # The near clip distance is the shortest distance which still contains all the corners
  _exit_camera.near = max(_EXIT_CAMERA_NEAR_MIN, min(d_1, d_2, d_3, d_4) - exit_near_subtract)
  _exit_camera.far = main_camera.far
  _exit_camera.fov = main_camera.fov
  _exit_camera.keep_aspect = main_camera.keep_aspect

## Return a new Transform3D relative to the exit portal based on the real Transform3D relative to this portal.
func real_to_exit_transform(real:Transform3D) -> Transform3D:
  # Convert from global space to local space at the entrance (this) portal
  var local:Transform3D = global_transform.affine_inverse() * real
  # Compensate for any scale the entrance portal may have
  var unscaled:Transform3D = local.scaled(global_transform.basis.get_scale())
  # Flip it (the portal always flips the view 180 degrees)
  var flipped:Transform3D = unscaled.rotated(Vector3.UP, PI)
  # Apply any scale the exit portal may have (and apply custom exit scale)
  var exit_scale_vector:Vector3 = exit_portal.global_transform.basis.get_scale()
  var scaled_at_exit:Transform3D = flipped.scaled(Vector3.ONE / exit_scale_vector * exit_scale)
  # Convert from local space at the exit portal to global space
  var local_at_exit:Transform3D = exit_portal.global_transform * scaled_at_exit
  return local_at_exit

## Return a new position relative to the exit portal based on the real position relative to this portal.
func real_to_exit_position(real:Vector3) -> Vector3:
  # Convert from global space to local space at the entrance (this) portal
  var local:Vector3 = global_transform.affine_inverse() * real
  # Compensate for any scale the entrance portal may have
  var unscaled:Vector3 = local * global_transform.basis.get_scale()
  # Apply any scale the exit portal may have (and apply custom exit scale)
  var exit_scale_vector:Vector3 = Vector3(-1, 1, 1) * exit_portal.global_transform.basis.get_scale()
  var scaled_at_exit:Vector3 = unscaled / exit_scale_vector * exit_scale
  # Convert from local space at the exit portal to global space
  var local_at_exit:Vector3 = exit_portal.global_transform * scaled_at_exit
  return local_at_exit

## Return a new direction relative to the exit portal based on the real direction relative to this portal.
func real_to_exit_direction(real:Vector3) -> Vector3:
  # Convert from global to local space at the entrance (this) portal
  var local:Vector3 = global_transform.basis.inverse() * real
  # Compensate for any scale the entrance portal may have
  var unscaled:Vector3 = local * global_transform.basis.get_scale()
  # Flip it (the portal always flips the view 180 degrees)
  var flipped:Vector3 = unscaled.rotated(Vector3.UP, PI)
  # Apply any scale the exit portal may have (and apply custom exit scale)
  var exit_scale_vector:Vector3 = exit_portal.global_transform.basis.get_scale()
  var scaled_at_exit:Vector3 = flipped / exit_scale_vector * exit_scale
  # Convert from local space at the exit portal to global space
  var local_at_exit:Vector3 = exit_portal.global_transform.basis * scaled_at_exit
  return local_at_exit

## Raycast against portals (See instructions).
static func raycast(tree:SceneTree, from:Vector3, dir:Vector3, handle_raycast:Callable,
  max_distance:float = INF, max_recursions:int = 16, ignore_backside:bool = true) -> void:
  var portals:Array = tree.get_nodes_in_group("portals")
  var ignore_portal:Portal = null
  var recursive_distance:float = 0

  for r in max_recursions + 1:
    var closest_hit:Vector3
    var closest_dir:Vector3
    var closest_portal:Portal
    var closest_distance_sqr:float = INF

    # Find the closest portal the ray intersects
    for portal in portals:
      # Ignore exit portals and invisible portals
      if portal == ignore_portal or not portal.is_inside_tree() or tree != portal.get_tree() or not portal.is_visible_in_tree():
        continue

      var local_from:Vector3 = portal.to_local(from)
      var local_dir:Vector3 = portal.global_transform.basis.inverse() * dir

      # Check if ray is parallel to the portal
      if local_dir.z == 0:
        continue

      # Ignore backside
      if local_dir.z > 0 and ignore_backside:
        continue

      # Get the intersection point of the ray with the Z axis
      var t:float = -local_from.z / local_dir.z

      # Is the intersection behind the start position?
      if t < 0:
        continue

      # Check if the ray hit inside the portal bounding box (ignoring Z)
      var local_hit:Vector3 = local_from + t * local_dir
      var aabb:AABB = portal._mesh_aabb
      if local_hit.x < aabb.position.x or local_hit.x > aabb.position.x + aabb.size.x or\
        local_hit.y < aabb.position.y or local_hit.y > aabb.position.y + aabb.size.y:
        continue

      # Check if this was the closest portal
      var hit:Vector3 = portal.to_global(local_hit)
      var distance_sqr:float = hit.distance_squared_to(from)
      if distance_sqr < closest_distance_sqr:
        closest_hit = hit
        closest_dir = dir
        closest_distance_sqr = distance_sqr
        closest_portal = portal

    # Calculate the ray distance
    var hit_distance:float = INF if is_inf(closest_distance_sqr) else sqrt(closest_distance_sqr)

    # Call the user-defined raycast function
    if handle_raycast.call(from, dir, hit_distance, recursive_distance, r):
      break

    # Was no portal hit or was the maximum raycast distance reached?
    recursive_distance += hit_distance
    if is_inf(closest_distance_sqr) or recursive_distance >= max_distance:
      break

    # Re-direct the ray through the portal
    from = closest_portal.real_to_exit_position(closest_hit)
    dir = closest_portal.real_to_exit_direction(closest_dir)
    ignore_portal = closest_portal.exit_portal

