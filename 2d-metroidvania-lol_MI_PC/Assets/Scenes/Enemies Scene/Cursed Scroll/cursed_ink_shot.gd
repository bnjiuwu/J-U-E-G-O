extends EnemyProjectile
class_name CursedInkShot

func _ready() -> void:
	super._ready()
	rotation = direction.angle()

func set_direction(dir: Vector2) -> void:
	super.set_direction(dir)
	rotation = direction.angle()
