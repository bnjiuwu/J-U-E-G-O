# res://Scripts/CaseItems/CaseInstakill.gd
extends CaseItem
class_name CaseInstakill

func _ready() -> void:
	# ✅ define valores del item aquí o por Inspector
	effect_name = "Instakill"
	duration = 15.0

func _apply(player: Node) -> void:
	if player and player.has_method("set_projectile_instakill"):
		player.set_projectile_instakill(true)

func _get_revert_callables(player: Node) -> Array[Callable]:
	var arr: Array[Callable] = []
	if player and player.has_method("set_projectile_instakill"):
		arr.append(Callable(player, "set_projectile_instakill").bind(false))
	return arr
