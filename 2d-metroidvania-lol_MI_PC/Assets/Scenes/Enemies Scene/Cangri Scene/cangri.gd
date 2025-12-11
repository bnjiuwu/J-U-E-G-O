extends CharacterBody2D
## Boss Cangri behaviour controller.
## Handles patrol, player targeting, charge attack, death sequence, and health UI label.

signal boss_health_changed(current: int, max: int, boss_name: String)
signal boss_died(boss_name: String)
signal boss_visibility_changed(is_visible: bool)

enum State { IDLE, WALK, BOOK_TRANSFORM, BOOK_CHARGE, BOOK_IMPACT, BOOK_SUMMON, RECOVER, DEATH }

const HOMING_BOOK_COUNT := 2

@export var boss_name: String = "CANGRI"
@export var player_group: StringName = &"player"
@export var max_health: int = 500
@export var gravity: float = 900.0
@export var patrol_speed: float = 45.0
@export var chase_speed: float = 110.0
@export var wander_time_min: float = 1.5
@export var wander_time_max: float = 3.0
@export var lose_target_distance: float = 1200.0
@export var book_trigger_distance: float = 520.0
@export var book_transform_time: float = 0.6
@export var book_dash_duration: float = 1.35
@export var book_speed: float = 500.0
@export var book_cooldown: float = 3.5
@export var contact_damage: int = 20
@export var book_damage: int = 55
@export var contact_recovery_delay: float = 0.45
@export var health_label_offset: Vector2 = Vector2(0, -200)
@export var sprite_faces_right: bool = true
@export var close_stop_distance: float = 70.0
@export var direction_deadzone: float = 10.0
@export var ghost_on_death: bool = true
@export var death_float_height: float = -24.0
@export var death_float_speed: float = 12.0
@export var homing_book_scene: PackedScene
@export var homing_book_trigger_distance: float = 900.0
@export var homing_book_min_distance: float = 260.0
@export var homing_book_cooldown: float = 6.0
@export var homing_book_windup: float = 0.35
@export var homing_book_pair_gap: float = 0.08
@export var homing_book_recover: float = 0.6
@export var homing_book_spawn_offset: Vector2 = Vector2(80, -40)
@export var homing_book_vertical_spacing: float = 24.0

var _state: State = State.IDLE
var _direction: int = 1
var _state_time: float = 0.0
var _health: int = 0
var _target: Node2D = null
var _wander_timer: float = 0.0
var _book_cooldown_timer: float = 0.0
var _is_dying: bool = false
var _boss_visible: bool = false
var _book_form_active: bool = false
var _homing_cooldown_timer: float = 0.0
var _next_homing_spawn_time: float = 0.0
var _homing_books_spawned: int = 0
var _summon_recover_time: float = -1.0

@onready var _sprite: AnimatedSprite2D = $Sprite if has_node("Sprite") else null
@onready var _detection: Area2D = $DetectionZone if has_node("DetectionZone") else null
@onready var _hitbox: Area2D = $Hitbox if has_node("Hitbox") else null
@onready var _health_label: Label = $HealthLabel if has_node("HealthLabel") else null
@onready var _visibility_notifier: VisibleOnScreenNotifier2D = $VisibilityNotifier if has_node("VisibilityNotifier") else null
@onready var _body_collision: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var _book_collision: CollisionShape2D = $BookCollisionShape2D if has_node("BookCollisionShape2D") else null
@onready var _left_ledge_check: RayCast2D = $LeftLedgeCheck if has_node("LeftLedgeCheck") else null
@onready var _right_ledge_check: RayCast2D = $RightLedgeCheck if has_node("RightLedgeCheck") else null

func _ready() -> void:
	randomize()
	_health = max_health
	_health_label.position = health_label_offset
	_health_label.text = "--"
	_health_label.visible = false
	_sync_sprite_flip()
	_set_book_collision(false)
	if _detection:
		_detection.body_entered.connect(_on_detection_body_entered)
		_detection.body_exited.connect(_on_detection_body_exited)
	if _hitbox:
		_hitbox.body_entered.connect(_on_hitbox_body_entered)
	if _visibility_notifier:
		if not _visibility_notifier.screen_entered.is_connected(_on_visibility_screen_entered):
			_visibility_notifier.screen_entered.connect(_on_visibility_screen_entered)
		if not _visibility_notifier.screen_exited.is_connected(_on_visibility_screen_exited):
			_visibility_notifier.screen_exited.connect(_on_visibility_screen_exited)
		if _visibility_notifier.is_on_screen():
			_on_visibility_screen_entered()
		else:
			_on_visibility_screen_exited()
	if _sprite and not _sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		_sprite.animation_finished.connect(_on_sprite_animation_finished)
	_enter_state(State.IDLE)
	_emit_health_update()

func _physics_process(delta: float) -> void:
	var is_dead := _state == State.DEATH
	if not is_dead:
		_book_cooldown_timer = max(0.0, _book_cooldown_timer - delta)
		_homing_cooldown_timer = max(0.0, _homing_cooldown_timer - delta)
		_apply_gravity(delta)
		_state_time += delta
		_update_target_reference()
		match _state:
			State.IDLE:
				_process_idle(delta)
			State.WALK:
				_process_walk(delta)
			State.BOOK_TRANSFORM:
				_process_book_transform()
			State.BOOK_CHARGE:
				_process_book_charge(delta)
			State.BOOK_IMPACT:
				_process_book_impact(delta)
			State.BOOK_SUMMON:
				_process_book_summon(delta)
			State.RECOVER:
				_process_recover(delta)
	else:
		velocity = Vector2.ZERO
		if ghost_on_death and _sprite:
			var target_y := death_float_height
			_sprite.position.y = lerpf(_sprite.position.y, target_y, delta * death_float_speed)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if _book_form_active:
		velocity.y = 0.0
		return
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = min(velocity.y, 0.0)

func _process_idle(delta: float) -> void:
	velocity.x = 0.0
	_wander_timer -= delta
	if _target and _can_launch_homing_books():
		_enter_state(State.BOOK_SUMMON)
		return
	if _target and _can_start_book_attack():
		_enter_state(State.BOOK_TRANSFORM)
		return
	if _target:
		_update_direction_towards_target(true)
		_enter_state(State.WALK)
		return
	if _wander_timer <= 0.0:
		_set_direction(-1 if randf() < 0.5 else 1)
		_wander_timer = randf_range(wander_time_min, wander_time_max)
		_enter_state(State.WALK)

func _process_walk(delta: float) -> void:
	var speed := patrol_speed
	var freeze_for_target := false
	if _target:
		speed = chase_speed
		var delta_x := _target.global_position.x - global_position.x
		if abs(delta_x) <= close_stop_distance:
			freeze_for_target = true
		else:
			_update_direction_towards_target()
		if _can_launch_homing_books():
			_enter_state(State.BOOK_SUMMON)
			return
		if _can_start_book_attack():
			_enter_state(State.BOOK_TRANSFORM)
			return
	velocity.x = _direction * speed
	if is_on_floor() and not _has_floor_ahead(_direction):
		_set_direction(-_direction)
		velocity.x = 0.0
		return
	if freeze_for_target:
		velocity.x = lerpf(velocity.x, 0.0, delta * 6.0)
	if _state_time >= _wander_timer and not _target:
		_enter_state(State.IDLE)
	else:
		velocity.x = clampf(velocity.x, -chase_speed, chase_speed)

func _process_book_transform() -> void:
	velocity = Vector2.ZERO
	if _state_time >= book_transform_time:
		_book_form_active = true
		_enter_state(State.BOOK_CHARGE)

func _process_book_charge(delta: float) -> void:
	velocity.x = _direction * book_speed
	velocity.y = 0.0
	if is_on_floor() and not _has_floor_ahead(_direction):
		_book_form_active = false
		_enter_state(State.RECOVER)
		return
	if _state_time >= book_dash_duration:
		_book_cooldown_timer = book_cooldown
		_book_form_active = false
		_enter_state(State.RECOVER)

func _process_book_impact(delta: float) -> void:
	velocity = Vector2.ZERO
	if _state_time >= contact_recovery_delay:
		_enter_state(State.RECOVER)

func _process_book_summon(delta: float) -> void:
	velocity = Vector2.ZERO
	if _target == null or not is_instance_valid(_target):
		_enter_state(State.RECOVER)
		return
	var pair_gap := maxf(homing_book_pair_gap, 0.0)
	var min_gap := pair_gap if pair_gap > 0.0 else 0.0001
	while _homing_books_spawned < HOMING_BOOK_COUNT and _state_time >= _next_homing_spawn_time:
		var spawn_index := _homing_books_spawned
		var side := -1 if spawn_index == 0 else 1
		var vertical_sign := -1 if spawn_index == 0 else 1
		var spawned := _spawn_homing_book(side, vertical_sign)
		if spawned:
			_homing_books_spawned += 1
			if _homing_books_spawned >= HOMING_BOOK_COUNT:
				_summon_recover_time = _state_time + homing_book_recover
			else:
				_next_homing_spawn_time += min_gap
		else:
			_homing_books_spawned = HOMING_BOOK_COUNT
			_summon_recover_time = _state_time + homing_book_recover
	var finished := _summon_recover_time > 0.0 and _state_time >= _summon_recover_time
	if finished:
		_enter_state(State.RECOVER)

func _process_recover(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, delta * 4.0)
	if _state_time >= 0.4:
		_enter_state(State.IDLE)

func _enter_state(new_state: State) -> void:
	if _is_dying and new_state != State.DEATH:
		return
	_state = new_state
	_state_time = 0.0
	match _state:
		State.IDLE:
			_book_form_active = false
			_set_book_collision(false)
			_play_anim("idle")
			_wander_timer = randf_range(wander_time_min, wander_time_max)
		State.WALK:
			_book_form_active = false
			_set_book_collision(false)
			_play_anim("walk")
		State.BOOK_TRANSFORM:
			velocity = Vector2.ZERO
			_face_target()
			_set_book_collision(false)
			_play_anim("book_transform", false)
		State.BOOK_CHARGE:
			_set_book_collision(true)
			_play_anim("book", true)
		State.BOOK_IMPACT:
			_book_form_active = true
			_set_book_collision(true)
			_play_anim("contact", false)
		State.RECOVER:
			_book_form_active = false
			_set_book_collision(false)
			_play_anim("idle")
		State.BOOK_SUMMON:
			velocity = Vector2.ZERO
			_book_form_active = false
			_set_book_collision(false)
			_face_target()
			_homing_books_spawned = 0
			_next_homing_spawn_time = homing_book_windup
			_homing_cooldown_timer = homing_book_cooldown
			_summon_recover_time = -1.0
			_play_anim("attack", false)
		State.DEATH:
			velocity = Vector2.ZERO
			_set_book_collision(false)
			_play_anim("death", false)

func _play_anim(name: String, loop: bool = true) -> void:
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(name):
		_sprite.animation = name
		_sprite.play()
		if _sprite.sprite_frames:
			_sprite.sprite_frames.set_animation_loop(name, loop)

func _update_target_reference() -> void:
	if _target and not is_instance_valid(_target):
		_target = null
	if _target and global_position.distance_to(_target.global_position) > lose_target_distance:
		_target = null
	if _target == null:
		var players := get_tree().get_nodes_in_group(player_group)
		var closest: Node2D = null
		var closest_distance := INF
		for candidate in players:
			if candidate is Node2D and is_instance_valid(candidate):
				var node := candidate as Node2D
				var dist := global_position.distance_to(node.global_position)
				if dist < closest_distance:
					closest_distance = dist
					closest = node
		if closest:
			_target = closest
			_update_direction_towards_target(true)

func _can_start_book_attack() -> bool:
	if _book_cooldown_timer > 0.0 or _target == null:
		return false
	if not is_instance_valid(_target):
		return false
	var dist := global_position.distance_to(_target.global_position)
	return dist <= book_trigger_distance and is_on_floor()

func _can_launch_homing_books() -> bool:
	if homing_book_scene == null:
		return false
	if _homing_cooldown_timer > 0.0:
		return false
	if _target == null or not is_instance_valid(_target):
		return false
	var dist := global_position.distance_to(_target.global_position)
	return dist >= homing_book_min_distance and dist <= homing_book_trigger_distance and is_on_floor()

func _face_target() -> void:
	if _target:
		_update_direction_towards_target(true)

func take_damage(amount: int) -> void:
	if _is_dying:
		return
	_health = max(_health - amount, 0)
	_emit_health_update()
	if _health <= 0:
		_start_death_sequence()

func _start_death_sequence() -> void:
	if _is_dying:
		return
	_is_dying = true
	_enter_state(State.DEATH)
	_play_anim("death", false)
	_disable_combat()
	_emit_health_update()
	boss_died.emit(boss_name)

func _disable_combat() -> void:
	set_deferred("collision_layer", 0)
	if _detection:
		_detection.monitorable = false
		_detection.monitoring = false
	if _hitbox:
		_hitbox.monitorable = false
		_hitbox.monitoring = false

func _on_detection_body_entered(body: Node) -> void:
	if body.is_in_group(player_group):
		_target = body as Node2D
		if _target:
			_update_direction_towards_target(true)

func _on_detection_body_exited(body: Node) -> void:
	if body == _target:
		_target = null
		_enter_state(State.IDLE)

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group(player_group) and body.has_method("take_damage"):
		var is_book_dash := _state == State.BOOK_CHARGE
		var damage := book_damage if is_book_dash else contact_damage
		body.take_damage(damage, global_position)
		if is_book_dash:
			_spawn_contact_vfx(body.global_position)
			_book_cooldown_timer = book_cooldown
			_book_form_active = true
			_enter_state(State.BOOK_IMPACT)

func _emit_health_update() -> void:
	var current: int = max(_health, 0)
	var reported_max: int = max_health if current > 0 else 0
	boss_health_changed.emit(current, reported_max, boss_name)
	if _health_label:
		if current > 0:
			_health_label.text = "%d / %d" % [current, max_health]
		else:
			_health_label.text = ""
		var show_label: bool = _boss_visible and current > 0
		_health_label.visible = show_label

func _on_visibility_screen_entered() -> void:
	_boss_visible = true
	boss_visibility_changed.emit(true)
	if _health_label:
		_health_label.visible = _health > 0

func _on_visibility_screen_exited() -> void:
	_boss_visible = false
	boss_visibility_changed.emit(false)
	if _health_label:
		_health_label.visible = false

func heal(amount: int) -> void:
	_health = clamp(_health + amount, 0, max_health)
	_emit_health_update()

func get_current_health() -> int:
	return max(_health, 0)

func get_max_health_value() -> int:
	return max_health

func is_visible_to_player() -> bool:
	return _boss_visible

func _on_sprite_animation_finished() -> void:
	if _state == State.DEATH:
		queue_free()

func randf_range(a: float, b: float) -> float:
	return randf() * (b - a) + a

func _set_direction(value: int) -> void:
	if value == 0:
		return
	_direction = -1 if value < 0 else 1
	_sync_sprite_flip()

func _sync_sprite_flip() -> void:
	if not _sprite:
		return
	var should_flip := _direction < 0 if sprite_faces_right else _direction > 0
	_sprite.flip_h = should_flip

func _update_direction_towards_target(force: bool = false) -> void:
	if not _target:
		return
	var delta_x := _target.global_position.x - global_position.x
	if not force and abs(delta_x) < direction_deadzone:
		return
	_set_direction(-1 if delta_x < 0 else 1)

func _spawn_contact_vfx(at_position: Vector2) -> void:
	if not _sprite or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation("contact"):
		return
	var parent := get_parent()
	if parent == null:
		return
	var frames := _sprite.sprite_frames.duplicate(true)
	frames.set_animation_loop("contact", false)
	var vfx := AnimatedSprite2D.new()
	vfx.sprite_frames = frames
	vfx.animation = "contact"
	vfx.flip_h = _sprite.flip_h
	vfx.global_position = at_position
	vfx.scale = _sprite.scale
	parent.add_child(vfx)
	vfx.play("contact")
	vfx.animation_finished.connect(func(): vfx.queue_free())

func _set_book_collision(active: bool) -> void:
	if _body_collision:
		_body_collision.set_deferred("disabled", active)
	if _book_collision:
		_book_collision.set_deferred("disabled", not active)

func _has_floor_ahead(dir: int) -> bool:
	if dir == 0:
		return true
	var check := _left_ledge_check if dir < 0 else _right_ledge_check
	if check == null:
		return true
	check.force_raycast_update()
	return check.is_colliding()

func _spawn_homing_book(side_multiplier: int, vertical_multiplier: int = 0) -> bool:
	if homing_book_scene == null:
		return false
	var projectile_instance := homing_book_scene.instantiate()
	if projectile_instance == null:
		return false
	var parent := get_parent()
	if parent == null:
		return false
	var facing := _direction if _direction != 0 else 1
	var offset := Vector2(
		homing_book_spawn_offset.x * side_multiplier * facing,
		homing_book_spawn_offset.y + homing_book_vertical_spacing * vertical_multiplier
	)
	var spawn_position := global_position + offset
	parent.add_child(projectile_instance)
	if projectile_instance is Node2D:
		(projectile_instance as Node2D).global_position = spawn_position
	var has_valid_target := _target != null and is_instance_valid(_target)
	if projectile_instance.has_method("set_target") and has_valid_target:
		projectile_instance.set_target(_target)
	var target_vector := Vector2(facing, 0)
	if has_valid_target:
		target_vector = _target.global_position - spawn_position
	if target_vector.length_squared() <= 0.01:
		target_vector = Vector2(facing, 0)
	if projectile_instance.has_method("set_direction"):
		projectile_instance.set_direction(target_vector.normalized())
	return true
