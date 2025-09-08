extends CharacterBody2D

var input
@export var move_speed = 100.0
@export var gravity = 10


func _physics_process(delta: float):
	var input_axis = Input.get_axis("move_left", "move_right")
	velocity.x = input_axis * move_speed
	move_and_slide() 
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass
	
	
	
