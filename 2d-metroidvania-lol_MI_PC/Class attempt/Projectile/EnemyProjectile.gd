extends Projectile
class_name EnemyProjectile

func _apply_damage(target):
	if target.is_in_group("player"):
		target.take_damage(damage)
		
			# desactivar colisión al primer impacto
	_disable_collision()
