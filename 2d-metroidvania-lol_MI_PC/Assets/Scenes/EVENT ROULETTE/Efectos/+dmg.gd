extends CaseItem
class_name ItemProjectileDamageUp

@export var bonus: int = 2

func _ready():
	duration = 20.0

func _on_apply(player):
	if player.has_method("add_projectile_damage_bonus"):
		player.add_projectile_damage_bonus(bonus)

func _on_expire(player):
	if player.has_method("add_projectile_damage_bonus"):
		player.add_projectile_damage_bonus(-bonus)
