extends Node2D
class_name JumpPad


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.get("jump_pad_height"):
		body.velocity.y -= body.jump_pad_height/2
		$Sprite2D/AnimationPlayer.play("active")
		
	pass # Replace with function body.
