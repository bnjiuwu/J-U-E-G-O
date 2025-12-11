# res://Scripts/CaseItem.gd
extends Node2D
class_name CaseItem

@export var effect_name: String = "Efecto"
@export var duration: float = 20.0

func apply_to(player: Node) -> void:
	if player == null:
		return

	_apply(player)

	# UI
	if player.has_method("register_effect"):
		player.register_effect(effect_name, duration)

	# ✅ Timer seguro aunque el item de la ruleta se destruya
	if duration > 0:
		var t := get_tree().create_timer(duration, true)

		# Revertir usando callables ligados al PLAYER
		var revert_cbs := _get_revert_callables(player)
		for cb in revert_cbs:
			if cb is Callable and cb.is_valid():
				t.timeout.connect(cb, CONNECT_ONE_SHOT)


		# Limpiar UI al final
		if player.has_method("unregister_effect"):
			t.timeout.connect(
				Callable(player, "unregister_effect").bind(effect_name),
				CONNECT_ONE_SHOT
			)

func _apply(player: Node) -> void:
	pass

# ✅ Cada hijo devuelve callables hacia métodos del Player
func _get_revert_callables(player: Node) -> Array:
	return []
