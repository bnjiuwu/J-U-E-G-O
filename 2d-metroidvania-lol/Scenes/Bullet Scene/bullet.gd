extends Area2D

@export var speed: float = 400
var direction: Vector2 = Vector2.RIGHT

func _physics_process(delta):
	position += direction * delta * speed
	rotation = direction.angle()
	
	if position.x < -1000 or position.x > 1000 or position.y < -1000 or position.y > 1000:
		queue_free()
