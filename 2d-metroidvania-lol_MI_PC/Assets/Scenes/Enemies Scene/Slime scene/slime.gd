extends EnemyGround
class_name Slime

@export var speed: float = 50

var damage_modulate_timer: float = 0.05

@onready var wall_check: RayCast2D = $wall_check
@onready var floor_check: RayCast2D = $floor_check

func ground_behavior(delta):
	velocity.x = direction * speed

	if wall_check.is_colliding():
		flip_direction()

	if floor_check and not floor_check.is_colliding() and is_on_floor():
		flip_direction()


func _on_area_2d_area_entered(area: Area2D) -> void:
	modulate = Color(1,0,0)
	take_damage(area.damage)
	await get_tree().create_timer(damage_modulate_timer).timeout
	modulate = Color(1,1,1)
