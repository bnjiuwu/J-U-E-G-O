extends EnemyProjectile
class_name GolemProjectile

@export var projectile_gravity: float = 260.0
@export var vertical_impulse: float = -220.0

func _ready() -> void:
	# Start moving using the base logic, then add an upward impulse so it arcs.
	super._ready()
	velocity.y += vertical_impulse

func _physics_process(delta: float) -> void:
	if not has_impacted:
		velocity.y += projectile_gravity * delta
	super._physics_process(delta)
