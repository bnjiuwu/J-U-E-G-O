extends EnemyProjectile
class_name AztikMissile

@export_group("Homing")
@export var homing_turn_rate: float = 6.0
@export var max_distance: float = 900.0
@export var player_group: StringName = "player"

var _target: Node2D
var _start_position: Vector2

func _ready() -> void:
	_start_position = global_position
	_refresh_target(true)
	super._ready()

func _physics_process(delta: float) -> void:
	if has_impacted:
		return

	_refresh_target()
	if _target:
		var desired: Vector2 = (_target.global_position - global_position).normalized()
		var factor: float = clamp(homing_turn_rate * delta, 0.0, 1.0)
		var blended: Vector2 = direction.lerp(desired, factor).normalized()
		if blended.length_squared() > 0.001:
			set_direction(blended)

	super._physics_process(delta)

	if max_distance > 0.0 and global_position.distance_to(_start_position) >= max_distance:
		impact()

func _refresh_target(force: bool = false) -> void:
	if _target and (not is_instance_valid(_target) or not _target.is_in_group(player_group)):
		_target = null

	if _target and not force:
		return

	var players: Array[Node] = get_tree().get_nodes_in_group(player_group)
	if players.is_empty():
		_target = null
		return

	var closest: Node2D = null
	var closest_dist: float = INF
	for candidate in players:
		var node := candidate as Node2D
		if node == null:
			continue
		var dist: float = node.global_position.distance_to(global_position)
		if dist < closest_dist:
			closest = node
			closest_dist = dist
	_target = closest
