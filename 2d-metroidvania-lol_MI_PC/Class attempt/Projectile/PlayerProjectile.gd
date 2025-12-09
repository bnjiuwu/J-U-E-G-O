extends Projectile
class_name PlayerProjectile

signal hit_enemy(damage_amount: int)

func _apply_damage(target):
	var receiver = target

	# si el área que tocamos pertenece a un enemigo
	if target is Area2D and target.get_parent() and target.get_parent().has_method("take_damage"):
		receiver = target.get_parent()

	if receiver and receiver.has_method("take_damage"):
		receiver.take_damage(damage)

		# ✅ cuenta impacto si el receptor es enemigo
		#    o si pegaste a hitbox enemiga
		if receiver.is_in_group("enemy") or (target is Area2D and target.is_in_group("enemy_hitbox")):
			hit_enemy.emit(damage)
