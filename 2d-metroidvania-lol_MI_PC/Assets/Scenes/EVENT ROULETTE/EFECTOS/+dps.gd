# res://Scripts/CaseFireRateUp.gd
extends CaseItem
class_name CaseFireRateUp

@export var mult: float = 0.6  # menor delay = más rápido

func _init():
	effect_name = "+ DPS"
	duration = 20.0

func _apply(player):
	player.set_fire_rate_mult(mult)

func _get_revert_callables(player):
	return [
		Callable(player, "set_fire_rate_mult").bind(1.0)
	]
