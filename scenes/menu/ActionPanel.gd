# Code made with love and care by Mymy/TuTiuTe
extends PanelContainer

var action_str := ""

@onready var action_label: Label = $HBoxContainer/ActionLabel
@onready var keyboard_button: Button = $HBoxContainer/HBoxContainer/KeyboardButton
@onready var joypad_button: Button = $HBoxContainer/HBoxContainer/JoypadButton

var current_keyboard_event : InputEvent = null
var current_joy_event : InputEvent = null

func _ready() -> void:
  set_process_input(false)
  keyboard_button.toggled.connect(func(val : bool): update_state(val, keyboard_button))
  joypad_button.toggled.connect(func(val : bool): update_state(val, joypad_button))

func update_action() -> void:
  action_label.text = " " + action_str.replace("_", " ").capitalize()

  for input_event in InputMap.action_get_events(action_str):
    if current_keyboard_event and current_joy_event:
      break
    if input_event is InputEventKey or\
     input_event is InputEventMouseButton and not current_keyboard_event:
      current_keyboard_event = input_event
    
    elif input_event is InputEventJoypadButton or\
     input_event is InputEventJoypadMotion and not current_joy_event:
      current_joy_event = input_event
  
  keyboard_button.text = current_keyboard_event.as_text().get_slice(" (", 0)

  if current_joy_event and current_joy_event is InputEventJoypadButton:
    joypad_button.text = joy_button_to_text(current_joy_event.button_index)
  elif current_joy_event and current_joy_event is InputEventJoypadMotion:
    joypad_button.text = joy_motion_to_text(current_joy_event.axis, current_joy_event.axis_value)
    
func update_state(button_state : bool, button : Button) -> void:
  set_process_input(button_state)
  if button_state:
    button.text = "..."
  else:
    update_action()

func _input(event: InputEvent) -> void:
  if current_keyboard_event != event and\
   (event is InputEventKey or event is InputEventMouseButton) and\
   keyboard_button.button_pressed:
    remap_action_keyboard(event)
  elif current_joy_event != event and\
   (event is InputEventJoypadButton or event is InputEventJoypadMotion) and\
   joypad_button.button_pressed:
    remap_action_joypad(event)

func remap_action_keyboard(event : InputEvent) -> void:
  InputMap.action_erase_event(action_str, current_keyboard_event)
  InputMap.action_add_event(action_str, event)
  current_keyboard_event = event
  keyboard_button.button_pressed = false

func remap_action_joypad(event : InputEvent) -> void:
  InputMap.action_erase_event(action_str, current_joy_event)
  InputMap.action_add_event(action_str, event)
  current_joy_event = event
  joypad_button.button_pressed = false
    
func joy_motion_to_text(axis : int, axis_value : float) -> String:
  match [axis, signf(axis_value)]:
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
      
  return "Unknown"

func joy_button_to_text(button_index : int) -> String:
  match button_index:
    JOY_BUTTON_A:
      return "A"
    JOY_BUTTON_B:
      return "B"
    JOY_BUTTON_X:
      return "X"
    JOY_BUTTON_Y:
      return "Y"
    JOY_BUTTON_LEFT_SHOULDER:
      return "LB"
    JOY_BUTTON_RIGHT_SHOULDER:
      return "RB"
  return "Unknown"
