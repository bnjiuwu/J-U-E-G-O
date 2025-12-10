extends EnemyProjectile
class_name AspidProjectile

@export var extra_speed: float = 0.0

func _ready() -> void:
	# aplicar velocidad adicional si queremos una bola más rápida
	if extra_speed != 0:
		velocity = direction.normalized() * (speed + extra_speed)

	super._ready()
