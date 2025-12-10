extends EnemyFlying
class_name CursedScroll

@export var patrol_speed: float = 38.0
@export var patrol_range: float = 120.0
@export var ranged_charge_time: float = 0.65
@export var ranged_cooldown: float = 1.6
@export var ink_scene: PackedScene
@export var ink_damage: int = 22
@export var ink_speed: float = 340.0
@export var ink_lifetime: float = 2.4
@export var suicide_charge_time: float = 0.8
@export var explosion_damage: int = 60
@export var explosion_duration: float = 0.7

@onready var range_zone: Area2D = $Detection/RangeZone
@onready var close_zone: Area2D = $Detection/CloseZone
@onready var projectile_muzzle: Marker2D = $ProjectileMuzzle
@onready var attack_timer: Timer = $Timers/AttackTimer
@onready var cooldown_timer: Timer = $Timers/CooldownTimer
@onready var suicide_timer: Timer = $Timers/SuicideTimer
@onready var explosion_timer: Timer = $Timers/ExplosionTimer
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_sprite: AnimatedSprite2D = $ExplosionSprite

enum State { PATROL, RANGED_WINDUP, RANGED_RECOVER, SUICIDE_CHARGE, EXPLODING }
var _state: State = State.PATROL
var _player_target: Node2D = null
var _player_in_range: bool = false
var _player_is_close: bool = false
var _patrol_anchor_x: float = 0.0
var _self_detonating: bool = false
var _explosion_damage_applied: bool = false

func _ready() -> void:
	super._ready()
	_patrol_anchor_x = global_position.x
	_setup_detection_zones()
	_setup_timers()
	_ensure_projectile_scene()
	is_attacking = false
	is_moving = true
	if explosion_sprite:
		explosion_sprite.visible = false
		explosion_sprite.stop()
		if not explosion_sprite.animation_finished.is_connected(_on_explosion_sprite_finished):
			explosion_sprite.animation_finished.connect(_on_explosion_sprite_finished)
	# Calm hover tuning for this enemy.
	hover_amplitude = 6.0
	hover_frequency = 1.4

func _ensure_projectile_scene() -> void:
	if ink_scene:
		return
	var default_path := "res://Assets/Scenes/Enemies Scene/Cursed Scroll/CursedInkShot.tscn"
	if ResourceLoader.exists(default_path):
		ink_scene = load(default_path)

func _setup_detection_zones() -> void:
	if range_zone:
		range_zone.body_entered.connect(_on_range_zone_body_entered)
		range_zone.body_exited.connect(_on_range_zone_body_exited)
	if close_zone:
		close_zone.body_entered.connect(_on_close_zone_body_entered)
		close_zone.body_exited.connect(_on_close_zone_body_exited)
	if explosion_area:
		explosion_area.monitoring = false
		explosion_area.body_entered.connect(_on_explosion_area_body_entered)

func _setup_timers() -> void:
	if attack_timer:
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	if cooldown_timer:
		cooldown_timer.one_shot = true
		cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	if suicide_timer:
		suicide_timer.one_shot = true
		suicide_timer.timeout.connect(_on_suicide_timer_timeout)
	if explosion_timer:
		explosion_timer.one_shot = true
		explosion_timer.timeout.connect(_on_explosion_timer_timeout)

func flying_behavior(delta: float) -> void:
	match _state:
		State.PATROL:
			_patrol_behavior(delta)
		State.RANGED_WINDUP:
			_ranged_windup_behavior(delta)
		State.RANGED_RECOVER:
			_ranged_recover_behavior(delta)
		State.SUICIDE_CHARGE:
			_suicide_charge_behavior(delta)
		State.EXPLODING:
			velocity = velocity.move_toward(Vector2.ZERO, 420.0 * delta)
	_update_directional_nodes()

func _patrol_behavior(delta: float) -> void:
	velocity.x = direction * patrol_speed
	if abs(global_position.x - _patrol_anchor_x) >= patrol_range:
		direction *= -1
	is_moving = true
	is_attacking = false

func _ranged_windup_behavior(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, patrol_speed * 5.0 * delta)
	is_moving = false
	is_attacking = true
	_face_player()

func _ranged_recover_behavior(delta: float) -> void:
	velocity.x = direction * (patrol_speed * 0.6)
	is_moving = true
	is_attacking = false

func _suicide_charge_behavior(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, patrol_speed * 6.0 * delta)
	is_moving = false
	is_attacking = true
	_face_player()

func _face_player() -> void:
	if not _player_target:
		return
	var diff := _player_target.global_position.x - global_position.x
	if diff == 0:
		return
	direction = 1 if diff > 0 else -1

func _on_range_zone_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_target = body
	_player_in_range = true
	if _state == State.PATROL and (not cooldown_timer or cooldown_timer.is_stopped()):
		_start_ranged_attack()

func _on_range_zone_body_exited(body: Node) -> void:
	if body == _player_target:
		_player_in_range = false
		if not _player_is_close:
			_player_target = null
		if not _player_is_close and _state in [State.RANGED_WINDUP, State.RANGED_RECOVER]:
			_cancel_ranged_attack()

func _on_close_zone_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_target = body
	_player_is_close = true
	_start_suicide_attack()

func _on_close_zone_body_exited(body: Node) -> void:
	if body == _player_target:
		_player_is_close = false
		if not _player_in_range:
			_player_target = null

func _start_ranged_attack() -> void:
	if _state != State.PATROL:
		return
	_state = State.RANGED_WINDUP
	if attack_timer:
		attack_timer.start(ranged_charge_time)
	is_attacking = true
	is_moving = false
	_face_player()

func _cancel_ranged_attack() -> void:
	if _state not in [State.RANGED_WINDUP, State.RANGED_RECOVER]:
		return
	if attack_timer:
		attack_timer.stop()
	if cooldown_timer:
		cooldown_timer.stop()
	_state = State.PATROL
	is_attacking = false

func _on_attack_timer_timeout() -> void:
	if _state == State.RANGED_WINDUP:
		_fire_ink_projectile()
		_state = State.RANGED_RECOVER
		if cooldown_timer:
			cooldown_timer.start(ranged_cooldown)

func _on_cooldown_timer_timeout() -> void:
	if _state == State.RANGED_RECOVER:
		_state = State.PATROL
		is_attacking = false
	if _player_in_range and _state == State.PATROL:
		_start_ranged_attack()

func _on_suicide_timer_timeout() -> void:
	if _state == State.SUICIDE_CHARGE:
		_trigger_explosion()

func _on_explosion_timer_timeout() -> void:
	if _state == State.EXPLODING:
		_finalize_self_destruction()

func _start_suicide_attack() -> void:
	if _state == State.EXPLODING:
		return
	_state = State.SUICIDE_CHARGE
	if attack_timer:
		attack_timer.stop()
	if cooldown_timer:
		cooldown_timer.stop()
	if suicide_timer:
		suicide_timer.start(suicide_charge_time)
	is_attacking = true
	is_moving = false
	_face_player()

func _trigger_explosion() -> void:
	if _state == State.EXPLODING:
		return
	_state = State.EXPLODING
	_self_detonating = true
	is_attacking = true
	is_moving = false
	_show_explosion_sprite()
	if attack_timer:
		attack_timer.stop()
	if cooldown_timer:
		cooldown_timer.stop()
	if suicide_timer:
		suicide_timer.stop()
	if explosion_timer:
		explosion_timer.start(explosion_duration)
	if explosion_area:
		explosion_area.monitoring = true
		explosion_area.monitorable = true
		_apply_explosion_damage()

func _apply_explosion_damage() -> void:
	if _explosion_damage_applied or not explosion_area:
		return
	_explosion_damage_applied = true
	for body in explosion_area.get_overlapping_bodies():
		_damage_body(body)

func _damage_body(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(explosion_damage, global_position)

func _on_explosion_area_body_entered(body: Node) -> void:
	if _state != State.EXPLODING:
		return
	_damage_body(body)

func _fire_ink_projectile() -> void:
	if not ink_scene:
		return
	var projectile := ink_scene.instantiate()
	var spawn_position := projectile_muzzle.global_position if projectile_muzzle else global_position
	var direction_vector := Vector2.RIGHT * direction
	if _player_target and is_instance_valid(_player_target):
		direction_vector = (_player_target.global_position - spawn_position).normalized()
	if projectile is Node2D:
		projectile.global_position = spawn_position
	if "damage" in projectile:
		projectile.damage = ink_damage
	if "speed" in projectile:
		projectile.speed = ink_speed
	if "lifetime" in projectile:
		projectile.lifetime = ink_lifetime
	if projectile.has_method("set_direction"):
		projectile.set_direction(direction_vector)
	elif "direction" in projectile:
		projectile.direction = direction_vector
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(projectile)
	else:
		add_child(projectile)

func _on_animation_finished() -> void:
	if sprite.animation == "attack2" and _state == State.SUICIDE_CHARGE:
		_trigger_explosion()
		return
	super._on_animation_finished()

func _on_explosion_sprite_finished() -> void:
	if _state == State.EXPLODING:
		_finalize_self_destruction()

func _finalize_self_destruction() -> void:
	if explosion_timer:
		explosion_timer.stop()
	if explosion_area:
		explosion_area.monitoring = false
	_self_detonating = true
	GlobalsSignals.enemy_defeated.emit()
	queue_free()

func die() -> void:
	if _self_detonating:
		GlobalsSignals.enemy_defeated.emit()
		queue_free()
		return
	super.die()

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Cursed Scroll only hurts through ink or explosion.
	pass

func _update_directional_nodes() -> void:
	var dir_sign := 1 if direction >= 0 else -1
	if range_zone:
		range_zone.position.x = dir_sign * abs(range_zone.position.x)
	if close_zone:
		close_zone.position.x = dir_sign * abs(close_zone.position.x)
	if projectile_muzzle:
		projectile_muzzle.position.x = dir_sign * abs(projectile_muzzle.position.x)

func update_animation() -> void:
	if not sprite:
		return
	if is_dead:
		sprite.play("death")
		return
	if _state == State.EXPLODING:
		return  # explosion visuals handled separately
	match _state:
		State.PATROL:
			sprite.play("walk")
		State.RANGED_WINDUP:
			sprite.play("attack1")
		State.RANGED_RECOVER:
			sprite.play("idle")
		State.SUICIDE_CHARGE:
			sprite.play("attack2")
		_:
			sprite.play("idle")

func _show_explosion_sprite() -> void:
	if sprite:
		sprite.visible = false
	if not explosion_sprite:
		return
	explosion_sprite.visible = true
	explosion_sprite.play("explosion")

