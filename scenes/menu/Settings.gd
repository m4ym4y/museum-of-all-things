extends Control

signal resume

@onready var _xr = Util.is_xr()
@onready var _vbox = $ScrollContainer/MarginContainer/VBoxContainer/MarginContainer
@onready var _tab_bar = $ScrollContainer/MarginContainer/VBoxContainer/TabBar
@onready var _tab_scenes = [
  _vbox.get_node("GraphicsSettings"),
  _vbox.get_node("AudioSettings"),
  _vbox.get_node("XrControlsMenu") if _xr else null,
  _vbox.get_node("DataSettings")
]

func _ready():
  GlobalMenuEvents.ui_cancel_pressed.connect(_on_resume)
  GlobalMenuEvents.menu_left_pressed.connect(_on_tab_left)
  GlobalMenuEvents.menu_right_pressed.connect(_on_tab_right)
  for i in range(_tab_scenes.size()):
    if _tab_scenes[i] == null:
      _tab_bar.set_tab_disabled(i, true)
      _tab_bar.set_tab_hidden(i, true)

func _on_visibility_changed():
  if visible:
    _tab_bar.set_current_tab(0)
    _tab_bar.grab_focus()

func _on_tab_bar_tab_changed(tab: int):
  for i in range(_tab_scenes.size()):
    if _tab_scenes[i] == null:
      continue
    elif i == tab:
      _tab_scenes[i].visible = true
    else:
      _tab_scenes[i].visible = false

func _on_tab_left():
  if visible:
    _tab_bar.select_next_available()

func _on_tab_right():
  if visible:
    _tab_bar.select_previous_available()

func _on_resume():
  if visible:
    emit_signal("resume")
