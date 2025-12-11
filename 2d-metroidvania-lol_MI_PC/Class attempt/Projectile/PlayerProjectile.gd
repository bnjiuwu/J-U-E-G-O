extends Projectile
class_name PlayerProjectile

signal hit_enemy(dmg: int)

var _damaged_targets: = {}

func apply_damage(target: Node) -> bool:
	if target == null or target == self:
		return false

	var receiver: Node = target

	# Si tocamos un hitbox Area2D de enemigo
	if target is Area2D:
		var parent := target.get_parent()
		if parent and parent.is_in_group("enemy") and target.is_in_group("enemy_hitbox"):
			receiver = parent

	if receiver and receiver.has_method("take_damage"):
		var key := receiver.get_instance_id()
		if _damaged_targets.has(key):
			return false
		receiver.take_damage(damage)
		hit_enemy.emit(damage)
		_damaged_targets[key] = true
		return true

	return false
