extends CharacterBody2D

# GOLEM ENEMY IMPLEMENTATION (Godot 4.5)
# Comportamiento: patrulla lenta, detecta jugador cerca y realiza una animación de lanzamiento.
# Animaciones requeridas: idle, walk, throw (se generan desde las hojas idle Golem.png, walk golem.png, throw golem.png).

signal boss_health_changed(current: int, max: int, boss_name: String)
signal boss_died(boss_name: String)
signal boss_visibility_changed(is_visible: bool)

enum State { IDLE, WALK, WINDUP, THROW, RECOVER, DEATH }

const FLOOR_CHECK_HORIZONTAL_OFFSET := 36.0
const WALL_CHECK_HORIZONTAL_OFFSET := 40.0
const WALL_CHECK_TARGET_X := 48.0

@export var patrol_speed: float = 32.0
@export var chase_speed: float = 120.0
@export var gravity: float = 900.0
@export var wander_time_min: float = 1.5
@export var wander_time_max: float = 3.5
@export var throw_distance: float = 420.0
@export var pursuit_distance: float = 720.0
@export var lose_target_distance: float = 900.0
@export var player_group: StringName = &"player"
@export var windup_time: float = 0.8
@export var recover_time: float = 0.6
@export var throw_release_delay: float = 0.35
@export var throw_cooldown: float = 1.4
@export var stationary_throw_cooldown: float = 2.6
@export var stationary_speed_threshold: float = 28.0
@export var max_health: int = 60
@export var contact_damage: int = 10
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 260.0
@export var projectile_damage: int = 55
@export var projectile_spawn_offset: Vector2 = Vector2(110, -20)
@export var predictive_aim_weight: float = 0.35
@export var predictive_aim_time_cap: float = 0.6
@export var footstep_shake_interval: float = 0.45
@export var footstep_shake_intensity: float = 8.0
@export var footstep_shake_duration: float = 0.14
@export var boss_zoom_enabled: bool = true
@export var boss_zoom: Vector2 = Vector2(0.85, 0.85)
@export var boss_zoom_in_time: float = 0.85
@export var boss_zoom_out_time: float = 0.65
@export var boss_ui_name: String = "GOLEM"

var _state: State = State.IDLE
var _direction: int = 1
var _state_time: float = 0.0
var _target: Node = null
var _health: int
var _timer_wander: float = 0.0
var _projectile_released: bool = false
var _footstep_timer: float = 0.0
var _camera_zoom_active: bool = false
var _throw_cooldown_timer: float = 0.0
var _target_velocity: Vector2 = Vector2.ZERO
var _target_speed: float = 0.0
var _last_target_position: Vector2 = Vector2.ZERO
var _has_last_target_position: bool = false
var _is_dying: bool = false
var _boss_visible_to_player: bool = false

@onready var _sprite: AnimatedSprite2D = $Sprite if has_node("Sprite") else null
@onready var _detection: Area2D = $DetectionZone if has_node("DetectionZone") else null
@onready var _hitbox: Area2D = $Hitbox if has_node("Hitbox") else null
@onready var _floor_raycast: RayCast2D = $FloorCheck if has_node("FloorCheck") else null
@onready var _wall_raycast: RayCast2D = $WallCheck if has_node("WallCheck") else null
@onready var _body_collision: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var _visibility_notifier: VisibleOnScreenNotifier2D = $VisibilityNotifier if has_node("VisibilityNotifier") else null

func _ready():
	randomize()
	_health = max_health
	_enter_state(State.IDLE)
	if _detection:
		_detection.body_entered.connect(_on_detection_body_entered)
		_detection.body_exited.connect(_on_detection_body_exited)
	if _hitbox:
		_hitbox.body_entered.connect(_on_hitbox_body_entered)
		_hitbox.area_entered.connect(_on_hitbox_area_entered)
	if _sprite and not _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.connect(_on_sprite_animation_finished)
	if _visibility_notifier:
		if not _visibility_notifier.screen_entered.is_connected(_on_visibility_screen_entered):
			_visibility_notifier.screen_entered.connect(_on_visibility_screen_entered)
		if not _visibility_notifier.screen_exited.is_connected(_on_visibility_screen_exited):
			_visibility_notifier.screen_exited.connect(_on_visibility_screen_exited)
		if _visibility_notifier.is_on_screen():
			_on_visibility_screen_entered()
		else:
			_on_visibility_screen_exited()
	_emit_health_update()

func _physics_process(delta: float) -> void:
	_throw_cooldown_timer = max(0.0, _throw_cooldown_timer - delta)
	_refresh_target_reference()
	_update_target_motion(delta)
	_apply_gravity(delta)
	_state_time += delta
	match _state:
		State.IDLE:
			_process_idle(delta)
		State.WALK:
			_process_walk(delta)
		State.WINDUP:
			if _state_time >= windup_time:
				_enter_state(State.THROW)
		State.THROW:
			_process_throw()
		State.RECOVER:
			if _state_time >= recover_time:
				_enter_state(State.IDLE)
		State.DEATH:
			velocity = Vector2.ZERO
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = min(velocity.y, 0)

func _process_idle(delta: float) -> void:
	if _target:
		if _can_throw_at_target():
			_enter_state(State.WINDUP)
			return
		_direction = -1 if _target.global_position.x < global_position.x else 1
		_timer_wander = randf_range(wander_time_min, wander_time_max)
		_enter_state(State.WALK)
		return
	_timer_wander -= delta
	if _timer_wander <= 0.0:
		_direction = -1 if randf() < 0.5 else 1
		_timer_wander = randf_range(wander_time_min, wander_time_max)
		_enter_state(State.WALK)

func _process_walk(delta: float) -> void:
	var current_speed := patrol_speed
	if _target:
		if _can_throw_at_target():
			_enter_state(State.WINDUP)
			return
		_direction = -1 if _target.global_position.x < global_position.x else 1
		current_speed = max(chase_speed, patrol_speed)
	velocity.x = _direction * current_speed
	_handle_flip()
	if _floor_raycast:
		_floor_raycast.force_raycast_update()
	if _wall_raycast:
		_wall_raycast.force_raycast_update()
	if _wall_raycast and _wall_raycast.is_colliding():
		_direction *= -1
	if _floor_raycast and not _floor_raycast.is_colliding():
		_direction *= -1
	if _state_time >= _timer_wander:
		_enter_state(State.IDLE)
		velocity.x = 0

	if is_on_floor() and footstep_shake_interval > 0.0:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_trigger_camera_shake()
			_footstep_timer = footstep_shake_interval

func _process_throw() -> void:
	# Mantenerse en la animación de lanzamiento hasta que termine el tiempo calculado.
	if not _projectile_released and _state_time >= throw_release_delay:
		_launch_projectile()
	var throw_duration := _get_animation_duration("throw")
	if throw_duration <= 0.0:
		throw_duration = 0.6
	if _state_time >= throw_duration:
		_enter_state(State.RECOVER)

func _can_throw_at_target() -> bool:
	if _throw_cooldown_timer > 0.0:
		return false
	if not _target or not is_instance_valid(_target):
		return false
	var target_node := _target as Node2D
	if target_node == null:
		return false
	var dist = global_position.distance_to(target_node.global_position)
	return dist <= throw_distance and is_on_floor()

func _enter_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	match _state:
		State.IDLE:
			_projectile_released = false
			_footstep_timer = 0.0
			velocity.x = 0
			_timer_wander = randf_range(wander_time_min, wander_time_max)
			_play_anim("idle")
		State.WALK:
			_projectile_released = false
			_footstep_timer = footstep_shake_interval
			_play_anim("walk")
		State.WINDUP:
			velocity.x = 0
			_face_target()
			_play_anim("throw", false)
			_projectile_released = false
		State.THROW:
			velocity.x = 0
			_play_anim("throw", false)
			_projectile_released = false
		State.RECOVER:
			_projectile_released = false
			_footstep_timer = 0.0
			_play_anim("idle")
		State.DEATH:
			velocity = Vector2.ZERO
			_play_anim("death", false)

func _play_anim(name: String, loop: bool = true) -> void:
	if _sprite:
		if _sprite.sprite_frames.has_animation(name):
			_sprite.animation = name
			_sprite.play()
			# Godot 4 no expone `loop` directo en AnimatedSprite2D; usar SpriteFrames
			if _sprite.sprite_frames:
				_sprite.sprite_frames.set_animation_loop(name, loop)
				if not loop and name == "throw":
					_sprite.frame = 0

func _handle_flip() -> void:
	if _sprite:
		_sprite.flip_h = _direction < 0
	if _floor_raycast:
		_floor_raycast.position.x = FLOOR_CHECK_HORIZONTAL_OFFSET * _direction
	if _wall_raycast:
		_wall_raycast.position.x = WALL_CHECK_HORIZONTAL_OFFSET * _direction
		_wall_raycast.target_position = Vector2(WALL_CHECK_TARGET_X * _direction, 0.0)

func _face_target() -> void:
	if _target:
		_direction = -1 if _target.global_position.x < global_position.x else 1
		_handle_flip()

func _launch_projectile() -> void:
	if _projectile_released or projectile_scene == null:
		return
	var projectile: Projectile = projectile_scene.instantiate() as Projectile
	if projectile == null:
		push_warning("Golem attempted to fire a projectile that does not inherit from Projectile.")
		return
	var spawn_position = global_position + Vector2(projectile_spawn_offset.x * _direction, projectile_spawn_offset.y)
	projectile.global_position = spawn_position
	var fire_direction = _get_projectile_direction(spawn_position)
	projectile.speed = projectile_speed
	projectile.damage = projectile_damage
	projectile.set_direction(fire_direction)
	var parent = get_tree().current_scene if get_tree() else get_parent()
	if parent:
		parent.add_child(projectile)
	else:
		add_child(projectile)
	_projectile_released = true
	_throw_cooldown_timer = _get_current_throw_cooldown()

func _get_projectile_direction(spawn_position: Vector2) -> Vector2:
	if _target and is_instance_valid(_target):
		var target_node := _target as Node2D
		if target_node:
			var aim_position := target_node.global_position
			var aim_offset := _compute_predictive_offset(spawn_position, aim_position)
			var raw_direction := (aim_position + aim_offset) - spawn_position
			if raw_direction.length_squared() < 1.0:
				raw_direction = Vector2(_direction, -0.15)
			return raw_direction.normalized()
	return Vector2(_direction, 0)

func _compute_predictive_offset(spawn_position: Vector2, target_position: Vector2) -> Vector2:
	if projectile_speed <= 0.0 or predictive_aim_weight <= 0.0:
		return Vector2.ZERO
	var travel_time := spawn_position.distance_to(target_position) / projectile_speed
	travel_time = clamp(travel_time, 0.0, predictive_aim_time_cap)
	if travel_time <= 0.0:
		return Vector2.ZERO
	return _target_velocity * travel_time * predictive_aim_weight

func _trigger_camera_shake() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for cam in tree.get_nodes_in_group("camera_shake"):
		if cam and cam.has_method("start_shake"):
			cam.start_shake(footstep_shake_intensity, footstep_shake_duration)
			break

func take_damage(amount: int) -> void:
	if _is_dying:
		return
	_health = max(_health - amount, 0)
	_emit_health_update()
	if _health <= 0:
		_start_death_sequence()

func _on_detection_body_entered(body: Node) -> void:
	if body.is_in_group(player_group):
		_target = body
		_reset_target_tracking()
		_sync_camera_zoom_state()

func _on_detection_body_exited(body: Node) -> void:
	if body == _target:
		_target = null
		if _state in [State.WINDUP, State.THROW]:
			_enter_state(State.IDLE)
		_reset_target_tracking()
		_sync_camera_zoom_state()

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var player_body := area.get_parent()
		if player_body and player_body.has_method("take_damage"):
			player_body.take_damage(contact_damage, global_position)
	elif area.has_method("take_damage"):
		area.take_damage(contact_damage)

func randf_range(a: float, b: float) -> float:
	return randf() * (b - a) + a

func _get_animation_duration(anim_name: String) -> float:
	if not _sprite or not _sprite.sprite_frames:
		return 0.0
	if not _sprite.sprite_frames.has_animation(anim_name):
		return 0.0
	var frames = _sprite.sprite_frames.get_frame_count(anim_name)
	var speed = max(_sprite.sprite_frames.get_animation_speed(anim_name), 0.01)
	return frames / speed

func _refresh_target_reference() -> void:
	var previous_target := _target
	if _target and not is_instance_valid(_target):
		_target = null
	var target_node := _target as Node2D
	if target_node:
		if global_position.distance_to(target_node.global_position) > lose_target_distance:
			_target = null
	else:
		_target = null
	if _target == null:
		var candidate := _find_closest_player()
		if candidate and global_position.distance_to(candidate.global_position) <= pursuit_distance:
			_target = candidate
	if _target != previous_target:
		_reset_target_tracking()
		_sync_camera_zoom_state()

func _update_target_motion(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		_reset_target_tracking()
		return
	var target_node := _target as Node2D
	if target_node == null:
		_reset_target_tracking()
		return
	var current_position := target_node.global_position
	if not _has_last_target_position:
		_last_target_position = current_position
		_has_last_target_position = true
		_target_velocity = Vector2.ZERO
		_target_speed = 0.0
		return
	var delta_pos: Vector2 = current_position - _last_target_position
	var safe_delta: float = max(delta, 0.0001)
	_target_velocity = delta_pos / safe_delta
	_target_speed = _target_velocity.length()
	_last_target_position = current_position

func _reset_target_tracking() -> void:
	_has_last_target_position = false
	_target_velocity = Vector2.ZERO
	_target_speed = 0.0

func _get_current_throw_cooldown() -> float:
	var base_cooldown := throw_cooldown
	if _target_speed <= stationary_speed_threshold:
		base_cooldown = max(stationary_throw_cooldown, throw_cooldown)
	return max(base_cooldown, 0.1)

func _find_closest_player() -> Node2D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var closest: Node2D = null
	var closest_dist := INF
	for node in tree.get_nodes_in_group(player_group):
		if node is Node2D and is_instance_valid(node):
			var node2d := node as Node2D
			var dist := global_position.distance_to(node2d.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = node2d
	return closest

func _sync_camera_zoom_state() -> void:
	if not boss_zoom_enabled:
		return
	var should_activate := _target != null
	if should_activate == _camera_zoom_active:
		return
	_camera_zoom_active = should_activate
	_broadcast_camera_zoom(_camera_zoom_active)

func _broadcast_camera_zoom(activate: bool) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for cam in tree.get_nodes_in_group("camera_shake"):
		if cam == null:
			continue
		if activate:
			if cam.has_method("transition_zoom"):
				cam.transition_zoom(boss_zoom, boss_zoom_in_time)
		else:
			if cam.has_method("restore_default_zoom"):
				cam.restore_default_zoom(boss_zoom_out_time)

func _force_camera_zoom_reset() -> void:
	if not _camera_zoom_active:
		return
	_camera_zoom_active = false
	_broadcast_camera_zoom(false)

func get_current_health() -> int:
	return max(_health, 0)

func get_max_health_value() -> int:
	return max_health

func is_visible_to_player() -> bool:
	return _boss_visible_to_player

func _start_death_sequence() -> void:
	_is_dying = true
	_force_camera_zoom_reset()
	_disable_combat_collision()
	_enter_state(State.DEATH)
	_emit_health_update()
	boss_died.emit(boss_ui_name)

func _disable_combat_collision() -> void:
	if _body_collision:
		_body_collision.set_deferred("disabled", true)
	if _detection:
		_detection.monitorable = false
		_detection.monitoring = false
	if _hitbox:
		_hitbox.monitorable = false
		_hitbox.monitoring = false
	if _floor_raycast:
		_floor_raycast.enabled = false
	if _wall_raycast:
		_wall_raycast.enabled = false

func _on_sprite_animation_finished() -> void:
	if _state == State.DEATH:
		queue_free()

func _emit_health_update() -> void:
	boss_health_changed.emit(max(_health, 0), max_health, boss_ui_name)

func _set_player_visibility(value: bool) -> void:
	if _boss_visible_to_player == value:
		return
	_boss_visible_to_player = value
	boss_visibility_changed.emit(_boss_visible_to_player)

func _on_visibility_screen_entered() -> void:
	_set_player_visibility(true)

func _on_visibility_screen_exited() -> void:
	_set_player_visibility(false)
