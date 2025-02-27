# Code made with love and care by Mymy/TuTiuTe
extends PanelContainer

signal joypad_button_updated(event : InputEvent)

var action_str := ""

@onready var action_label: Label = $HBoxContainer/ActionLabel
@onready var keyboard_button: Button = $HBoxContainer/HBoxContainer/KeyboardButton
@onready var joypad_button: Button = $HBoxContainer/HBoxContainer/JoypadButton

var current_keyboard_event : InputEvent = null
var current_joypad_event : InputEvent = null

func _ready() -> void:
  set_process_input(false)
  keyboard_button.toggled.connect(func(val : bool): _on_button_toggled_aux(val, keyboard_button))
  joypad_button.toggled.connect(func(val : bool): _on_button_toggled_aux(val, joypad_button))
  
  keyboard_button.focus_exited.connect(func(): _on_focus_exited_aux(keyboard_button))
  joypad_button.focus_exited.connect(func(): _on_focus_exited_aux(joypad_button))

func update_action() -> void:
  action_label.text = " " + action_str.replace("_", " ").capitalize()

  for input_event in InputMap.action_get_events(action_str):
    if current_keyboard_event and current_joypad_event:
      break
    if input_event is InputEventKey or\
      input_event is InputEventMouseButton and not current_keyboard_event:
        current_keyboard_event = input_event
    
    elif input_event is InputEventJoypadButton or\
      input_event is InputEventJoypadMotion and not current_joypad_event:
        current_joypad_event = input_event
  
  keyboard_button.text = current_keyboard_event.as_text().get_slice(" (", 0)

  if current_joypad_event and current_joypad_event is InputEventJoypadButton:
    joypad_button.text = joy_button_to_text(current_joypad_event)
  elif current_joypad_event and current_joypad_event is InputEventJoypadMotion:
    joypad_button.text = joy_motion_to_text(current_joypad_event)
    
func _on_button_toggled_aux(button_state : bool, button : Button) -> void:
  set_process_input(button_state)
  if button_state:
    button.text = "..."
  else:
    update_action()
  joypad_button_updated.emit(current_joypad_event)

func _on_focus_exited_aux(button : Button) -> void:
  button.button_pressed = false
  set_process_input(joypad_button.pressed or joypad_button.pressed)
  update_action()

func _input(event: InputEvent) -> void:
  if current_keyboard_event != event and\
    (event is InputEventKey or event is InputEventMouseButton) and\
    keyboard_button.button_pressed:
      remap_action_keyboard(event)
  elif current_joypad_event != event and\
    (event is InputEventJoypadButton or event is InputEventJoypadMotion) and\
    joypad_button.button_pressed:
      remap_action_joypad(event)

func remap_action_keyboard(event : InputEvent) -> void:
  InputMap.action_erase_event(action_str, current_keyboard_event)
  InputMap.action_add_event(action_str, event)
  current_keyboard_event = event
  keyboard_button.button_pressed = false

func remap_action_joypad(event : InputEvent) -> void:
  InputMap.action_erase_event(action_str, current_joypad_event)
  InputMap.action_add_event(action_str, event)
  current_joypad_event = event
  joypad_button.button_pressed = false
    
func joy_motion_to_text(event : InputEventJoypadMotion) -> String:
  match [event.axis, signf(event.axis_value)]:
    [0, -1.0]:
      return "L Stick Left"
    [0, 1.0]:
      return "L Stick Right"
    [1, -1.0]:
      return "L Stick Down"
    [1, 1.0]:
      return "L Stick Up"
    
    [2, -1.0]:
      return "R Stick Left"
    [2, 1.0]:
      return "R Stick Right"
    [3, -1.0]:
      return "R Stick Down"
    [3, 1.0]:
      return "R Stick Up"
      
    [4, _]:
      return "LT"
    [5, _]:
      return "RT"
      
  return "Axis %d %1.1f" % [event.axis, event.axis_value]


func joy_button_to_text(event : InputEventJoypadButton) -> String:
  var connected_joypads := Input.get_connected_joypads()
  var joypad_name := Input.get_joy_name(max(connected_joypads[0], event.device)) if connected_joypads != [] else ""
  var brand := "Xbox"
  match joypad_name:
    "PS", "PlayStation":
      brand = "Sony"
    "Nintendo":
      brand = "Nintendo"
  return event.as_text().get_slice(brand + " ", 1).get_slice(",", 0).rstrip(")")
  #return "Button %d" % event.button_index
