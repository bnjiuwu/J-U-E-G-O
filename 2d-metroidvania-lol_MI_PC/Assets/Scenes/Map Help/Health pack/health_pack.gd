extends Node2D
@onready var label:= $Label
var ctn_health = 3
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$Sprite2D/AnimationPlayer.play("buh")
	label.text = str(ctn_health)
	
	if ctn_health <= 0:
		queue_free()
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.health < 100 and body.health + 20 > 100:
		body.health = 100
		ctn_health -= 1
		
	if body.health < 100 and body.health + 20 <= 100:
		body.health += 20
		ctn_health -= 1

	pass # Replace with function body.
