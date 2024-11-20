"""
  Asset: Godot Simple Portal System
  File: portal.gd
  Description: An area which teleports the player through the parent node's portal.
  Instructions: For detailed documentation, see the README or visit: https://github.com/Donitzo/godot-simple-portal-system
  Repository: https://github.com/Donitzo/godot-simple-portal-system
  License: CC0 License
"""

extends Area3D
class_name PortalTeleport

var _parent_portal

func _ready():
  _parent_portal = get_parent()
  if _parent_portal == null:
    push_error("The PortalTeleport \"%s\" is not a child of a Portal instance" % name)

  print("CREATED PORTAL")
  connect("area_entered", _on_area_entered)

func _on_area_entered(area:Area3D):
  print("CREATED PORTAL")
  if area.has_meta("teleportable_root"):
    var root:Node3D = area.get_node(area.get_meta("teleportable_root"))
    root.global_transform = _parent_portal.real_to_exit_transform(root.global_transform)
