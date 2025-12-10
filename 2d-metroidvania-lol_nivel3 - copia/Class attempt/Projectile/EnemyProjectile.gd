extends Projectile
class_name EnemyProjectile

func _apply_damage(target):
	if has_impacted:
		return

	if target.is_in_group("player") and target.has_method("take_damage"):
		target.take_damage(damage, global_position)
