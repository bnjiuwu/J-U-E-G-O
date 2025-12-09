extends CaseItem
class_name ItemNoDash

func _ready():
	duration = 20.0

func _on_apply(player):
	if player.has_method("set_dash_enabled"):
		player.set_dash_enabled(false)

func _on_expire(player):
	if player.has_method("set_dash_enabled"):
		player.set_dash_enabled(true)
