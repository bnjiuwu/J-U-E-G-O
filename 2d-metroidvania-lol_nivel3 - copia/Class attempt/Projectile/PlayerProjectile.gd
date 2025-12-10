extends Projectile
class_name PlayerProjectile


func _apply_damage(target):
	var receiver = target

	# si el área que tocamos pertenece a un enemigo
	if target is Area2D and target.get_parent().has_method("take_damage"):
		receiver = target.get_parent()
	
	if receiver.has_method("take_damage"):
		receiver.take_damage(damage)
