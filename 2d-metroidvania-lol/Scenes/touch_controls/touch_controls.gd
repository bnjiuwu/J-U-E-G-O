extends CanvasLayer

@onready var fire_btn: TouchScreenButton = $Node2D/TouchScreenButton


@onready var fire_button: Button = $Action_buttons/FIRE
@onready var dash_button: Button  = $Action_buttons/DASH
@onready var jump_button: Button = $Action_buttons/JUMP

func _ready():
	pass
	
#======== fire buton =============
func _on_fire_button_down() -> void:
	Input.action_press("attack")
	pass # Replace with function body.
	
func _on_fire_button_up() -> void:
	Input.action_release("attack")
	pass # Replace with function body.
#======== dash buton =============	
func _on_dash_button_down() -> void:
	Input.action_press("dash")
	pass # Replace with function body.

func _on_dash_button_up() -> void:
	Input.action_release("dash")
	pass # Replace with function body.
#======== jump buton =============

func _on_jump_button_down() -> void:
	Input.action_press("jump")
	pass # Replace with function body.

func _on_jump_button_up() -> void:
	Input.action_release("jump")
	pass # Replace with function body.


func _on_pause_pressed() -> void:
	
	
	pass # Replace with function body.
