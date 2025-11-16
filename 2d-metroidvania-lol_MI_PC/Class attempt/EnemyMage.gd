extends Enemy
class_name EnemyRanged

@export var attack_range := 200.0
@export var attack_cooldown := 1.5
var attack_timer := 0.0

var player_target: CharacterBody2D = null

func enemy_behavior(delta):
	if is_dead:
		return

	# actualizar cooldown
	if attack_timer > 0:
		attack_timer -= delta

	if player_target:
		ranged_behavior(delta)
	else:
		patrol_behavior(delta)

func ranged_behavior(delta):
	pass  # override

func patrol_behavior(delta):
	pass  # override

func try_attack() -> bool:
	if attack_timer <= 0:
		attack_timer = attack_cooldown
		is_attacking = true
		return true
	return false
