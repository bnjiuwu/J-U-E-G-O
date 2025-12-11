extends EnemyFlying
class_name Moski

# --- Ajustes copiados del murciélago ---
@export var patrol_speed: float = 60.0
@export var dive_speed: float = 260.0
@export var retreat_speed: float = 180.0
@export var attack_cooldown: float = 1.5
@export var charge_time: float = 0.5
@export var flip_cooldown: float = 0.4
@export var dive_duration: float = 2.0
@export var wave_amp: float = 40.0
@export var wave_freq_ms: float = 400.0
@export var kick_strength: float = 180.0
@export var kick_duration: float = 0.15

@export var dir_change_interval: float = 5.5
@export var dir_change_chance: float = 0.4

var _dir_change_timer: float = 0.0

var _flip_lock := 0.0
var _attack_cooldown_timer := 0.0
var _charge_timer := 0.0
var _retreat_timer := 0.0
var _detect_lock_timer := 0.0
var _dive_timer := 0.0
var _lift_cooldown := 0.0

var _kick_timer: float = 0.0
var _kick_dir: int = 0

enum State { PATROL, CHARGING, DIVE, RETREAT }
var current_state = State.PATROL
var player_target: CharacterBody2D = null

var dive_direction: Vector2 = Vector2.ZERO

@onready var wall_check: RayCast2D = $WallCheck
@onready var floor_check: RayCast2D = $FloorCheck
@onready var ceiling_check: RayCast2D = $CeilingCheck
@onready var detection_zone: Area2D = $DetectionZone


func _ready() -> void:
	super._ready()
	randomize()
	_setup_sensors()


func flying_behavior(delta: float) -> void:
	if is_dead:
		return

	_flip_lock = max(_flip_lock - delta, 0.0)
	_lift_cooldown = max(_lift_cooldown - delta, 0.0)
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	if _detect_lock_timer > 0.0:
		_detect_lock_timer -= delta

	match current_state:
		State.PATROL:
			_patrol_behavior(delta)
		State.CHARGING:
			_charge_behavior(delta)
		State.DIVE:
			_dive_behavior(delta)
		State.RETREAT:
			_retreat_behavior(delta)

	if current_state in [State.PATROL, State.RETREAT]:
		_check_floor_and_lift(delta)
		_check_ceiling_and_lower(delta)

	if sprite:
		sprite.flip_h = (direction == 1)

	is_moving = true

	_update_directional_nodes()


func _setup_sensors():
	if wall_check:
		wall_check.enabled = true
	if floor_check:
		floor_check.enabled = true
	if ceiling_check:
		ceiling_check.enabled = true
	if detection_zone:
		detection_zone.monitoring = true
		detection_zone.monitorable = true


func _update_directional_nodes():
	if wall_check:
		wall_check.position.x = sign(direction) * abs(wall_check.position.x)
		wall_check.target_position.x = sign(direction) * abs(wall_check.target_position.x)

	if detection_zone:
		detection_zone.position.x = sign(direction) * abs(detection_zone.position.x)


func _patrol_behavior(delta: float) -> void:
	velocity.x = direction * patrol_speed

	var extra_wave := sin(Time.get_ticks_msec() / wave_freq_ms) * wave_amp

	var hit_floor := floor_check and floor_check.is_colliding()
	var hit_ceiling := ceiling_check and ceiling_check.is_colliding()

	if _kick_timer <= 0.0:
		if hit_floor:
			var dist_ok := true
			if floor_check:
				var d = floor_check.get_collision_point().y - global_position.y
				dist_ok = d < 25.0
			if dist_ok:
				_kick_dir = -1
				_kick_timer = kick_duration
		elif hit_ceiling:
			var dist_ok2 := true
			if ceiling_check:
				var d2 = global_position.y - ceiling_check.get_collision_point().y
				dist_ok2 = d2 < 25.0
			if dist_ok2:
				_kick_dir = +1
				_kick_timer = kick_duration

	var kick_vy := 0.0
	if _kick_timer > 0.0:
		_kick_timer -= delta
		var t: float = clamp(_kick_timer / kick_duration, 0.0, 1.0)
		kick_vy = _kick_dir * kick_strength * t
	else:
		_kick_dir = 0

	velocity.y = hover_base_y + extra_wave + kick_vy

	var hitting_wall := wall_check and wall_check.is_colliding()
	if hitting_wall and _flip_lock <= 0.0:
		_flip()
		_dir_change_timer = 0.0

	if not hitting_wall:
		_dir_change_timer += delta
		if _dir_change_timer >= dir_change_interval:
			_dir_change_timer = 0.0
			if randf() <= dir_change_chance:
				_flip()

	is_attacking = false
	is_moving = true


func _charge_behavior(delta: float) -> void:
	_charge_timer -= delta
	velocity = Vector2.ZERO

	if detection_zone:
		detection_zone.monitoring = false
		detection_zone.monitorable = false

	if _charge_timer <= 0.0:
		if player_target:
			direction = 1 if player_target.global_position.x > global_position.x else -1
			_update_directional_nodes()
			dive_direction = (player_target.global_position - global_position).normalized()
		else:
			dive_direction = Vector2(direction, 0)

		current_state = State.DIVE
		_dive_timer = dive_duration
		_detect_lock_timer = 1.8


func _dive_behavior(delta: float) -> void:
	_dive_timer -= delta
	velocity = dive_direction * dive_speed

	if detection_zone:
		detection_zone.monitoring = false
		detection_zone.monitorable = false

	if wall_check and wall_check.is_colliding():
		var normal := wall_check.get_collision_normal()
		if abs(normal.x) > 0.5:
			_on_attack_hit_player()
	elif _dive_timer <= 0.0:
		current_state = State.PATROL
		player_target = null
		_detect_lock_timer = 0.8
		if detection_zone:
			detection_zone.monitoring = true
			detection_zone.monitorable = true


func _retreat_behavior(delta: float) -> void:
	_retreat_timer -= delta
	velocity = Vector2(-direction, 0).normalized() * retreat_speed

	if _retreat_timer <= 0.0:
		current_state = State.PATROL
		player_target = null
		_detect_lock_timer = 0.5
		if detection_zone:
			detection_zone.monitoring = true
			detection_zone.monitorable = true


func _on_attack_hit_player() -> void:
	_retreat_timer = 0.6
	current_state = State.RETREAT
	_attack_cooldown_timer = attack_cooldown
	_detect_lock_timer = 1.5


func _check_floor_and_lift(delta: float) -> void:
	if not floor_check:
		return

	if floor_check.is_colliding():
		var dist_to_floor := floor_check.get_collision_point().y - global_position.y
		if dist_to_floor < 25.0:
			var target_y := -120.0
			velocity.y = lerp(velocity.y, target_y, 8.0 * delta)
			velocity.y = -180.0
			_lift_cooldown = 0.3


func _check_ceiling_and_lower(delta: float) -> void:
	if not ceiling_check:
		return

	if ceiling_check.is_colliding():
		var dist_to_ceiling := global_position.y - ceiling_check.get_collision_point().y
		if dist_to_ceiling < 25.0:
			var target_y := 120.0
			velocity.y = lerp(velocity.y, target_y, 8.0 * delta)


func _flip() -> void:
	direction *= -1
	_flip_lock = flip_cooldown
	if wall_check:
		wall_check.enabled = false
		wall_check.position.x *= -1
		wall_check.target_position.x *= -1
		call_deferred("_re_enable_wallcheck")


func _re_enable_wallcheck() -> void:
	if wall_check:
		wall_check.enabled = true


func _on_DetectionArea_body_entered(body: Node) -> void:
	if _detect_lock_timer > 0.0 or current_state in [State.CHARGING, State.DIVE, State.RETREAT]:
		return

	if body.is_in_group("player"):
		player_target = body
		_charge_timer = charge_time
		current_state = State.CHARGING


func _on_DetectionArea_body_exited(body: Node) -> void:
	if body == player_target and current_state == State.PATROL:
		player_target = null
