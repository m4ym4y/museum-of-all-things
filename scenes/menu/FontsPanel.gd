extends PanelContainer


var font_str := ""

@onready var font_label: Button = $VBoxContainer/FontLabel


var current_font_label : Button = null
var picked_font : String = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
   pass # Replace with function body.

func update_font() -> void:
   font_label.text = " " + font_str
   var font_path = OS.get_system_font_path(font_str)
   font_label.add_theme_font_override("font",load_system_font(font_path))
   current_font_label = font_label


func load_system_font(path: String) -> Font:
   var path_lower = path.to_lower()
   var font_file = FontFile.new()
   if (  path_lower.ends_with(".ttf")
      or path_lower.ends_with(".otf")
      or path_lower.ends_with(".woff")
      or path_lower.ends_with(".woff2")
      or path_lower.ends_with(".pfb")
      or path_lower.ends_with(".pfm")):
      font_file.load_dynamic_font(path)
   elif path_lower.ends_with(".fnt") or path_lower.ends_with(".font"):
      font_file.load_bitmap_font(path) 
   else:
      push_error("Invalid font file format.")

   return font_file
   
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


#func _on_font_label_pressed() -> void:
  
 #   picked_font = current_font_label.text
