extends Enemy
class_name BossEnemy

signal boss_defeated
signal boss_died(boss_name: String)

@export var boss_display_name: String = ""

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
	boss_died.emit(_get_boss_name())

func _get_boss_name() -> String:
	return boss_display_name if boss_display_name.length() > 0 else name
