# res://Scripts/CaseNoDash.gd
extends CaseItem
class_name CaseNoDash

func _init():
	effect_name = "No Dash"
	duration = 20.0

func _apply(player):
	player.set_dash_enabled(false)

func _get_revert_callables(player):
	return [
		Callable(player, "set_dash_enabled").bind(true)
	]
