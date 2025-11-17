extends Enemy
class_name EnemyGround

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func enemy_behavior(delta: float) -> void:
	# gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	ground_behavior(delta)

	# movimiento horizontal
	move_and_slide()
	is_moving = abs(velocity.x) > 0.1

	# flip del sprite
	if sprite_faces_right:
		sprite.flip_h = (direction == -1)
	else:
		sprite.flip_h = (direction == 1)


func ground_behavior(delta: float) -> void:
	pass


func flip_direction() -> void:
	direction *= -1

	for child in get_children():
		if child is RayCast2D:
			child.position.x *= -1
			child.target_position.x *= -1
