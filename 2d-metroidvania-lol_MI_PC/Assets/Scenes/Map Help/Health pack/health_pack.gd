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

var health_timer: float = 0.2

func _on_area_2d_body_entered(body: Node2D) -> void:
	body.modulate = Color(0.0, 0.852, 0.0, 1.0)
	if body.health < 100 and body.health + 20 > 100:
		body.health = 100
		await body.get_tree().create_timer(health_timer).timeout
		body.modulate = Color(1.0, 1.0, 1.0, 1.0)
		body._update_health_bar()
		ctn_health -= 1
		
	if body.health < 100 and body.health + 20 <= 100:
		body.health += 20
		await body.get_tree().create_timer(health_timer).timeout
		body.modulate = Color(1.0, 1.0, 1.0, 1.0)
		ctn_health -= 1
		body._update_health_bar()
	body.modulate = Color(1.0, 1.0, 1.0, 1.0)
	pass # Replace with function body.
