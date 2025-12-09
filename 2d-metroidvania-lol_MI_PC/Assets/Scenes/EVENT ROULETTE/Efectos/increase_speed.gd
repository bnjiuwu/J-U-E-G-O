extends CaseItem
class_name ItemMoveSpeedUp

@export var bonus: float = 60.0

func _ready():
	duration = 20.0

func _on_apply(player):
	if player.has_method("add_move_speed_bonus"):
		player.add_move_speed_bonus(bonus)

func _on_expire(player):
	if player.has_method("add_move_speed_bonus"):
		player.add_move_speed_bonus(-bonus)
