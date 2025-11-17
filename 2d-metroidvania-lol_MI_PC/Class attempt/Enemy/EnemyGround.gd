extends Enemy
class_name EnemyGround

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func enemy_behavior(delta: float) -> void:
	# gravedad básica
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# comportamiento específico (slime, mago, etc.)
	ground_behavior(delta)

	# mover primero
	move_and_slide()

	# luego detectar movimiento horizontal correcto
	is_moving = abs(velocity.x) > 0.1

func ground_behavior(delta: float) -> void:
	pass


# 🔥🔥 LA FUNCIÓN IMPORTANTE: VOLTEA DIRECCIÓN + RAYCASTS 🔥🔥
func flip_direction() -> void:
	direction *= -1

	# VOLTEAR TODOS LOS RAYCAST DE ESTE ENEMIGO
	for child in get_children():
		if child is RayCast2D:
			child.position.x = -child.position.x
			child.target_position.x = -child.target_position.x
