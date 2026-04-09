extends CanvasLayer


@onready var Jump = $UITouchScreenControl/BottomRightGridContainer/JumpButton
@onready var Interact = $UITouchScreenControl/BottomRightGridContainer/InteractButton
@onready var Crouch = $UITouchScreenControl/BottomRightGridContainer/CrouchButton
@onready var Dash = $UITouchScreenControl/BottomRightGridContainer/DashButton


func _ready():
	Jump.connect("pressed", Callable(self, "On_Jump_Pressed"))
	Jump.connect("released", Callable(self, "On_Jump_Released"))

	Interact.connect("pressed", Callable(self, "On_Interact_Pressed"))
	Interact.connect("released", Callable(self, "On_Interact_Released"))

	Crouch.connect("pressed", Callable(self, "On_Crouch_Pressed"))
	Crouch.connect("released", Callable(self, "On_Crouch_Released"))

	Dash.connect("pressed", Callable(self, "On_Dash_Pressed"))
	Dash.connect("released", Callable(self, "On_Dash_Released"))


func On_Jump_Pressed():
	Input.action_press("jump")


func On_Jump_Released():
	Input.action_release("jump")


func On_Interact_Pressed():
	Input.action_press("interact")


func On_Interact_Released():
	Input.action_release("interact")


func On_Crouch_Pressed():
	Input.action_press("crouch")


func On_Crouch_Released():
	Input.action_release("crouch")


func On_Dash_Pressed():
	Input.action_press("dash")


func On_Dash_Released():
	Input.action_release("dash")
