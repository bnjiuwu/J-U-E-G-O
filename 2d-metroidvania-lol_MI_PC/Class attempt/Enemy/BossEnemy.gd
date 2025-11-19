extends Enemy
class_name BossEnemy

signal boss_defeated

func flip() -> void:
	# Cambiar dirección horizontal
	direction *= -1

	# Flip visual genérico para cualquier jefe
	if sprite:
		if sprite_faces_right:
			sprite.flip_h = (direction == -1)
		else:
			sprite.flip_h = (direction == 1)


func die() -> void:
	if is_dead:
		return

	# Lógica de muerte base (vida, anim, señal global, etc.)
	super.die()

	# Señal específica de jefe
	boss_defeated.emit()
