# res://Scripts/CaseSpeedDown.gd
extends CaseItem
class_name CaseSpeedDown

@export var bonus: float = -60.0

func _init():
	effect_name = "- Speed"
	duration = 20.0

func _apply(player):
	player.add_move_speed_bonus(bonus)

func _get_revert_callables(player):
	return [
		Callable(player, "add_move_speed_bonus").bind(-bonus)
	]
