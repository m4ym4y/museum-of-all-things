extends VBoxContainer

signal resume


const FONTS_PANEL = preload("res://scenes/menu/FontsPanel.tscn")
@onready var fonts_container: VBoxContainer = $FontsContainer
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    
    var system_fonts = OS.get_system_fonts()
    for font_str in system_fonts:
        var fonts_panel := FONTS_PANEL.instantiate()
        fonts_panel.font_str = font_str.replace("_", " ").capitalize()
        fonts_panel.name = font_str + " Panel"
        fonts_container.add_child(fonts_panel)
        fonts_panel.update_font()
    for font in fonts_container.get_children():
        font.get_child(0).get_child(0).pressed.connect(_on_picked.bind(font))
        
        
func _on_picked(font):
    $Search.text = ""
    $Search.text_changed.emit(font.font_str)
    var font_path = OS.get_system_font_path(font.font_str)
    #.add_theme_font_override("font",load_system_font(font_path))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass



func _on_search_text_changed(new_text: String) -> void:
    for font in fonts_container.get_children():   
       if new_text.to_lower() in font.current_font_label.text.to_lower():
            font.show()
       elif new_text == "":
             font.show()
       else: font.hide()
        
  

func _on_visibility_changed() -> void:
    pass
  #if _loaded_settings and not visible:
    #_save_settings()


func _save_settings() -> void:
  #SettingsManager.save_settings(_control_ns, _create_settings_obj())
  pass
func _on_resume() -> void:
  _save_settings()
  emit_signal("resume")

func _on_restore_defaults_button_pressed() -> void:
  InputMap.load_from_project_settings()
  #update_all_maps_label()
  $MouseOptions/InvertY.button_pressed = false
  $MouseOptions/Sensitivity.value = 1.0
  $JoyOptions/Deadzone.value = 0.05
        
func _on_list_fonts_toggled(toggled_on: bool) -> void:
  $Search.text = ""
  $Search/ListFonts.text = "Hide" if toggled_on else "Show"
  for font in fonts_container.get_children():
    font.hide()
    if toggled_on:       
        font.show()


    
