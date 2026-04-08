extends CanvasLayer


@onready var Pause = $UITouchScreenControl/PauseButton


func _ready():
	Pause.connect("pressed", Callable(self, "On_Pause_Pressed"))


func On_Pause_Pressed():
	Input.action_press("pause")
