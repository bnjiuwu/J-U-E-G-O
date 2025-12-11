extends EnemyFlying
class_name Maskut

@export var patrol_range: float = 300.0
@export var move_speed: float = 60.0
@export var attack_cooldown: float = 2.0
@export var attack_spread_deg: float = 25.0
@export var projectile_scene: PackedScene

@export var ideal_distance: float = 150.0
@export var retreat_speed: float = 100.0

var player_target: CharacterBody2D = null
var in_combat: bool = false

@onready var spawn_point: Node2D = $ShootSpawnPoint
@onready var attack_timer: Timer = $AttackTimer
@onready var detection_area: Area2D = $DetectionArea

var start_position: Vector2
var left_limit: float
var right_limit: float
const PATROL_EPSILON := 2.0

@export var patrol_switch_time: float = 15.0
var patrol_timer: float = 0.0


func _ready() -> void:
	super._ready()

	start_position = global_position
	patrol_timer = patrol_switch_time

	left_limit = start_position.x - patrol_range
	right_limit = start_position.x + patrol_range

	if not detection_area.body_entered.is_connected(_on_DetectionArea_body_entered):
		detection_area.body_entered.connect(_on_DetectionArea_body_entered)
	if not detection_area.body_exited.is_connected(_on_DetectionArea_body_exited):
		detection_area.body_exited.connect(_on_DetectionArea_body_exited)

	attack_timer.wait_time = attack_cooldown
	if not attack_timer.timeout.is_connected(_on_AttackTimer_timeout):
		attack_timer.timeout.connect(_on_AttackTimer_timeout)
	attack_timer.start()


func flying_behavior(delta: float) -> void:
	if in_combat and player_target:
		_combat_movement(delta)
	else:
		_patrol_movement(delta)


func _patrol_movement(delta: float) -> void:
	patrol_timer -= delta
	if patrol_timer <= 0.0:
		direction *= -1
		patrol_timer = patrol_switch_time

	if is_on_wall():
		direction *= -1
		patrol_timer = patrol_switch_time

	velocity.x = move_speed * float(direction)

	if sprite:
		sprite.flip_h = (direction == -1)

	is_attacking = false


func _combat_movement(delta: float) -> void:
	if not player_target:
		return

	var to_player: Vector2 = player_target.global_position - global_position
	var distance := to_player.length()

	if distance > ideal_distance + 40.0:
		velocity.x = move_speed * sign(to_player.x)
	elif distance < ideal_distance - 40.0:
		velocity.x = -retreat_speed * sign(to_player.x)
	else:
		velocity.x = 0.0

	var dx := to_player.x
	if abs(dx) > 8.0:
		var desired_flip := dx < 0.0
		if desired_flip != sprite.flip_h:
			sprite.flip_h = desired_flip


func _on_AttackTimer_timeout() -> void:
	if in_combat and player_target and not is_dead:
		attack()


func attack() -> void:
	if not projectile_scene or not player_target:
		return

	is_attacking = true

	var base_dir: Vector2 = (player_target.global_position - spawn_point.global_position).normalized()

	for angle in [-attack_spread_deg, 0.0, attack_spread_deg]:
		var proj = projectile_scene.instantiate()
		proj.global_position = spawn_point.global_position

		var dir := base_dir.rotated(deg_to_rad(angle))
		if "set_direction" in proj:
			proj.set_direction(dir)

		get_tree().current_scene.add_child(proj)


func _on_DetectionArea_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_target = body
		in_combat = true

		var dx := player_target.global_position.x - global_position.x
		sprite.flip_h = dx < 0.0


func _on_DetectionArea_body_exited(body: Node) -> void:
	if body == player_target:
		player_target = null
		in_combat = false
