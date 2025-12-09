extends CaseItem
class_name ItemMaxHealthLevelUp

@export var amount: int = 20

func apply_to(player: Node) -> void:
	if player.has_method("increase_max_health"):
		player.increase_max_health(amount)
