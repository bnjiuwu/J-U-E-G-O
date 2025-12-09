# res://Scripts/CaseProjectileDamageUp.gd
extends CaseItem
class_name CaseProjectileDamageUp

@export var bonus: int = 2

func _init():
	effect_name = "+ DMG Bullet"
	duration = 20.0

func _apply(player):
	player.add_projectile_damage_bonus(bonus)

func _get_revert_callables(player):
	return [
		Callable(player, "add_projectile_damage_bonus").bind(-bonus)
	]
