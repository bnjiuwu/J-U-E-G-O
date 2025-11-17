extends Enemy
class_name EnemyFlying

@export var hover_amplitude: float = 20.0
@export var hover_frequency: float = 3.0
@export var move_speed: float = 60.0

var hover_time: float = 0.0

func enemy_behavior(delta: float) -> void:
	flying_behavior(delta)


func flying_behavior(delta: float) -> void:
	hover_time += delta * hover_frequency
	velocity.y = sin(hover_time) * hover_amplitude

	move_and_slide()
