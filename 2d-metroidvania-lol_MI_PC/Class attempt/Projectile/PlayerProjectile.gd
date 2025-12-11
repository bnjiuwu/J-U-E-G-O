extends Projectile
class_name PlayerProjectile

signal hit_enemy(dmg: int)

func apply_damage(target: Node) -> bool:
	if target == null or target == self:
		return false

	var receiver: Node = target

	# Si tocamos un hitbox Area2D de enemigo
	if target is Area2D:
		var parent := target.get_parent()
		if parent and parent.is_in_group("enemy"):
			receiver = parent

	if receiver and receiver.has_method("take_damage"):
		receiver.take_damage(damage)
		hit_enemy.emit(damage)
		return true

	return false
