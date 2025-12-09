# res://Scripts/CaseInstakill.gd
extends CaseItem
class_name CaseInstakill

func _init():
	effect_name = "Instakill"
	duration = 15.0

func _apply(player):
	player.set_projectile_instakill(true)

func _get_revert_callables(player):
	return [
		Callable(player, "set_projectile_instakill").bind(false)
	]
