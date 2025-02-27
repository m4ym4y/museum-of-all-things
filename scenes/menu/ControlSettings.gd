# Code made with love and care by Mymy/TuTiuTe
extends VBoxContainer

signal resume

const ACTION_PANEL = preload("res://scenes/menu/ActionPanel.tscn")
@onready var mapping_container: VBoxContainer = $MappingContainer

var _control_ns := "control"
var _loaded_settings := false
var remappable_actions_str := [
    "move_forward",
    "move_back",
    "strafe_left",
    "strafe_right",
    "jump",
    "crouch",
    "interact",
]
var current_joypad_id := 0

func _ready() -> void:
    populate_map_buttons()
    var settings = SettingsManager.get_settings(_control_ns)
    _loaded_settings = true
    if settings:
        load_settings_obj(settings)

func populate_map_buttons() -> void:
    for action_str in remappable_actions_str:
        var action_panel := ACTION_PANEL.instantiate()
        action_panel.action_str = action_str
        action_panel.name = action_str + " Panel"
        mapping_container.add_child(action_panel)
        action_panel.update_action()
        action_panel.joypad_button_updated.connect(on_joypad_button_updated)

func on_joypad_button_updated(event : InputEvent) -> void:
  if current_joypad_id != event.device:
    for action_panel in mapping_container.get_children():
      if action_panel.current_joypad_event.device and\
       action_panel.current_joypad_event.device != event.device:
        action_panel.current_joypad_event.device = event.device
        action_panel.update_action()
    current_joypad_id = event.device
  
func _create_settings_obj() -> Dictionary:
    var save_dict := {}
    for action_panel in mapping_container.get_children():
        var save_event_joy := []
        var save_event_key := []

        if action_panel.current_keyboard_event is InputEventKey:
            save_event_key = [0, [action_panel.current_keyboard_event.device, action_panel.current_keyboard_event.keycode,
            action_panel.current_keyboard_event.physical_keycode, action_panel.current_keyboard_event.unicode]]
        elif action_panel.current_keyboard_event is InputEventMouseButton:
            save_event_key = [1, action_panel.current_keyboard_event.button_index]
        
        if action_panel.current_joypad_event is InputEventJoypadButton:
            save_event_joy = [0, action_panel.current_joypad_event.button_index]
        elif action_panel.current_joypad_event is InputEventJoypadMotion:
            save_event_joy = [1, [action_panel.current_joypad_event.axis, signf(action_panel.current_joypad_event.axis_value)]]
        
        save_dict[action_panel.action_str] = {"key_event" : save_event_key, "joy_event" : save_event_joy}
    return save_dict

func load_settings_obj(dict : Dictionary) -> void:
    for elt in dict:
        var action_panel : PanelContainer = mapping_container.get_node_or_null(elt + " Panel")
        if not action_panel:
            continue
        var event_key : InputEvent = null
        var event_joy : InputEvent = null
        
        if dict[elt]["key_event"][0] == 0:
            event_key = InputEventKey.new()
            event_key.device = dict[elt]["key_event"][1][0]
            event_key.keycode = dict[elt]["key_event"][1][1]
            event_key.physical_keycode = dict[elt]["key_event"][1][2]
            event_key.unicode = dict[elt]["key_event"][1][3]
        elif dict[elt]["key_event"][0] == 1:
            event_key = InputEventMouseButton.new()
            event_key.button_index = dict[elt]["key_event"][1]
        
        if dict[elt]["joy_event"][0] == 0:
            event_joy = InputEventJoypadButton.new()
            event_joy.button_index = dict[elt]["joy_event"][1]
        elif dict[elt]["joy_event"][0] == 1:
            event_joy = InputEventJoypadMotion.new()
            event_joy.axis = dict[elt]["joy_event"][1][0]
            event_joy.axis_value = dict[elt]["joy_event"][1][1]
        
        if event_key:
            action_panel.remap_action_keyboard(event_key)
        if event_joy:
            action_panel.remap_action_joypad(event_joy)
        action_panel.update_action()

func _on_visibility_changed() -> void:
    if _loaded_settings and not visible:
        _save_settings()

func _save_settings() -> void:
    SettingsManager.save_settings(_control_ns, _create_settings_obj())

func _on_resume() -> void:
    _save_settings()
    emit_signal("resume")
