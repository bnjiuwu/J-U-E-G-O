# res://Scripts/CaseMaxHealthUp.gd
extends CaseItem
class_name CaseMaxHealthUp

@export var amount: int = 20

func _init():
	effect_name = "+ Max HP"
	duration = 0.0

func _apply(player):
	player.increase_max_health(amount)
