# res://Scripts/CaseNoDoubleJump.gd
extends CaseItem
class_name CaseNoDoubleJump

func _init():
	effect_name = "No 2nd Jump"
	duration = 20.0

func _apply(player):
	player.set_double_jump_enabled(false)

func _get_revert_callables(player):
	return [
		Callable(player, "set_double_jump_enabled").bind(true)
	]
