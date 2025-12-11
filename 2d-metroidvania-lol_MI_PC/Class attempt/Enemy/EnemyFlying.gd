extends Enemy
class_name EnemyFlying

@export var hover_amplitude: float = 25.0
@export var hover_frequency: float = 3.0

var hover_time: float = 0.0
var hover_base_y: float = 0.0

func enemy_behavior(delta: float) -> void:
	# Hover vertical básico
	hover_time += delta * hover_frequency
	hover_base_y = sin(hover_time) * hover_amplitude
	velocity.y = hover_base_y

	# IA específica del volador (Bat, Aspid, etc.)
	flying_behavior(delta)

	# Movimiento físico general
	move_and_slide()


func flying_behavior(delta: float) -> void:
	# Lo sobrescriben PrimalAspid, Bat, etc.
	pass
