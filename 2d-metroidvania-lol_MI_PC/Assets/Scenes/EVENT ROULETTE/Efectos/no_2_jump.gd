extends CaseItem
class_name ItemNoDoubleJump

func _ready():
	duration = 20.0

func _on_apply(player):
	if player.has_method("set_double_jump_enabled"):
		player.set_double_jump_enabled(false)

func _on_expire(player):
	if player.has_method("set_double_jump_enabled"):
		player.set_double_jump_enabled(true)
