extends EnemyProjectile
class_name CangriHomingBook

@export var homing_turn_speed: float = 6.0

var _target: Node2D

func set_target(target: Node2D) -> void:
	_target = target

func _physics_process(delta: float) -> void:
	if not has_impacted:
		_update_homing_direction(delta)
	super._physics_process(delta)

func _update_homing_direction(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var to_target := _target.global_position - global_position
	if to_target.length_squared() <= 0.001:
		return
	var desired := to_target.normalized()
	var current := direction.normalized()
	var blend_factor := clampf(homing_turn_speed * delta, 0.0, 1.0)
	var new_direction := current.lerp(desired, blend_factor).normalized()
	set_direction(new_direction)
