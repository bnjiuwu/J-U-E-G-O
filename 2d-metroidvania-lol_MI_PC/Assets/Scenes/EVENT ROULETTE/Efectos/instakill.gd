extends CaseItem
class_name ItemProjectileInstakill

func _ready():
	duration = 15.0

func _on_apply(player):
	if player.has_method("set_projectile_instakill"):
		player.set_projectile_instakill(true)

func _on_expire(player):
	if player.has_method("set_projectile_instakill"):
		player.set_projectile_instakill(false)
