extends CaseItem
class_name ItemFireRateUp

@export var new_mult: float = 0.7

func _ready():
	duration = 20.0

func _on_apply(player):
	if player.has_method("set_fire_rate_mult"):
		player.set_fire_rate_mult(new_mult)

func _on_expire(player):
	if player.has_method("set_fire_rate_mult"):
		player.set_fire_rate_mult(1.0)
