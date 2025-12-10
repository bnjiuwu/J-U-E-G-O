extends Enemy
class_name DonCangrejo

@export var patrol_speed: float = 40.0
@export var teleport_distance: float = 150.0
@export var teleport_gap: float = 16.0
@export var ground_check_distance: float = 180.0
@export var teleport_out_duration: float = 0.5
@export var teleport_in_duration: float = 0.35
@export var attack_cooldown: float = 1.2
@export var attack_damage: int = 18
@export var ground_collision_mask: int = 1
@export var gravity: float = 1800.0

@export_range(0.0, 64.0, 1.0) var ground_snap_offset: float = 12.0

@onready var detection_zone: Area2D = $DetectionZone
@onready var teleport_out_timer: Timer = $Timers/TeleportOutTimer
@onready var teleport_in_timer: Timer = $Timers/TeleportInTimer
@onready var attack_cooldown_timer: Timer = $Timers/AttackCooldownTimer
@onready var attack_area: Area2D = $AttackArea
@onready var floor_check: RayCast2D = $Sensors/FloorCheck
@onready var edge_check: RayCast2D = $Sensors/EdgeCheck
@onready var wall_check: RayCast2D = $Sensors/WallCheck
@onready var body_shape: CollisionShape2D = $CollisionShape2D

enum State { PATROL, TELEPORT_OUT, TELEPORT_IN, ATTACK, COOLDOWN }
var _state: State = State.PATROL
var _player_target: CharacterBody2D = null
var _player_in_zone: bool = false
var _computed_ground_offset: float = 12.0
var _computed_half_width: float = 16.0

func _ready() -> void:
	super._ready()
	if detection_zone:
		detection_zone.body_entered.connect(_on_detection_zone_body_entered)
		detection_zone.body_exited.connect(_on_detection_zone_body_exited)
	teleport_out_timer.timeout.connect(_on_teleport_out_timeout)
	teleport_in_timer.timeout.connect(_on_teleport_in_timeout)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timeout)
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.monitoring = false
	_computed_ground_offset = _calculate_ground_offset()
	_computed_half_width = _calculate_body_half_width()
	_update_directional_nodes()

func enemy_behavior(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	match _state:
		State.PATROL, State.COOLDOWN:
			_patrol_behavior()
		_:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
			is_moving = false
	move_and_slide()

func _patrol_behavior() -> void:
	velocity.x = direction * patrol_speed
	is_moving = true
	is_attacking = false
	_check_direction_changes()

func _check_direction_changes() -> void:
	if wall_check and wall_check.is_colliding():
		_flip_direction()
		return
	if edge_check and not edge_check.is_colliding():
		_flip_direction()

func _flip_direction() -> void:
	_set_direction(-direction)

func _set_direction(value: int) -> void:
	if value == 0:
		value = 1
	direction = clamp(value, -1, 1)
	_update_directional_nodes()

func _update_directional_nodes() -> void:
	var s := float(direction)
	if wall_check:
		wall_check.position.x = s * abs(wall_check.position.x)
		wall_check.target_position.x = s * abs(wall_check.target_position.x)
	if edge_check:
		edge_check.position.x = s * abs(edge_check.position.x)
		edge_check.target_position.x = s * abs(edge_check.target_position.x)
	if floor_check:
		floor_check.position.x = s * abs(floor_check.position.x)
	if detection_zone:
		detection_zone.position.x = s * abs(detection_zone.position.x)
		var shape := detection_zone.get_node_or_null("CollisionShape2D")
		if shape:
			shape.position.x = s * abs(shape.position.x)
	if attack_area:
		attack_area.position.x = s * abs(attack_area.position.x)

func _on_detection_zone_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_target = body
	_player_in_zone = true
	if _state in [State.PATROL, State.COOLDOWN]:
		_begin_teleport_sequence()

func _on_detection_zone_body_exited(body: Node) -> void:
	if body == _player_target:
		_player_target = null
		_player_in_zone = false

func _begin_teleport_sequence() -> void:
	if not _player_target or not is_instance_valid(_player_target):
		return
	if _state in [State.TELEPORT_OUT, State.TELEPORT_IN, State.ATTACK]:
		return
	_state = State.TELEPORT_OUT
	attack_area.monitoring = false
	teleport_in_timer.stop()
	teleport_out_timer.stop()
	teleport_out_timer.start(teleport_out_duration)
	velocity = Vector2.ZERO
	is_moving = false

func _on_teleport_out_timeout() -> void:
	if _state != State.TELEPORT_OUT:
		return
	if not _player_target or not is_instance_valid(_player_target):
		_enter_cooldown()
		return
	global_position = _pick_teleport_position()
	velocity = Vector2.ZERO
	_state = State.TELEPORT_IN
	teleport_in_timer.start(teleport_in_duration)

func _on_teleport_in_timeout() -> void:
	if _state != State.TELEPORT_IN:
		return
	_start_attack_sequence()

func _start_attack_sequence() -> void:
	_state = State.ATTACK
	is_attacking = true
	attack_area.monitoring = true

func _on_attack_area_body_entered(body: Node) -> void:
	if _state != State.ATTACK:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(attack_damage, global_position)

func _enter_cooldown() -> void:
	attack_area.monitoring = false
	is_attacking = false
	_state = State.COOLDOWN
	attack_cooldown_timer.stop()
	attack_cooldown_timer.start(attack_cooldown)

func _on_attack_cooldown_timeout() -> void:
	_state = State.PATROL
	if _player_in_zone:
		_begin_teleport_sequence()

func _pick_teleport_position() -> Vector2:
	var player_pos := _player_target.global_position
	var player_dir := _player_facing_direction()
	var snug_distance := _calculate_snug_distance()
	var candidates := [
		Vector2(player_pos.x - player_dir * snug_distance, player_pos.y),
		Vector2(player_pos.x - player_dir * teleport_distance, player_pos.y),
		Vector2(player_pos.x + player_dir * snug_distance, player_pos.y),
		Vector2(player_pos.x + player_dir * teleport_distance, player_pos.y),
		Vector2(player_pos.x, player_pos.y)
	]
	for candidate in candidates:
		var grounded := _find_grounded_spot(candidate.x, candidate.y)
		if grounded != Vector2.INF:
			_face_player(player_pos, grounded)
			return grounded
	return global_position

func _player_facing_direction() -> int:
	if _player_target:
		var facing_value = _player_target.get("is_facing_right")
		if typeof(facing_value) == TYPE_BOOL:
			return 1 if facing_value else -1
		if _player_target.global_position.x < global_position.x:
			return -1
	return 1

func _find_grounded_spot(target_x: float, reference_y: float) -> Vector2:
	var start_y := reference_y - ground_check_distance * 0.25
	var start := Vector2(target_x, start_y)
	var finish := start + Vector2(0.0, ground_check_distance)
	var params := PhysicsRayQueryParameters2D.create(start, finish)
	params.collision_mask = ground_collision_mask
	params.exclude = [self]
	if _player_target:
		params.exclude.append(_player_target)
	var result := get_world_2d().direct_space_state.intersect_ray(params)
	if result.is_empty():
		return Vector2.INF
	var hit_position: Vector2 = result["position"]
	return Vector2(target_x, hit_position.y - _computed_ground_offset)

func _face_player(player_pos: Vector2, target_pos: Vector2) -> void:
	var dir := 1 if player_pos.x >= target_pos.x else -1
	_set_direction(dir)

func _calculate_ground_offset() -> float:
	if body_shape and body_shape.shape:
		if body_shape.shape is RectangleShape2D:
			return body_shape.position.y + body_shape.shape.size.y * 0.5
		if body_shape.shape is CapsuleShape2D:
			return body_shape.position.y + body_shape.shape.height * 0.5
	return ground_snap_offset

func _calculate_body_half_width() -> float:
	if body_shape and body_shape.shape:
		return _half_width_from_shape(body_shape.shape)
	return 16.0

func _calculate_snug_distance() -> float:
	var player_half := _player_half_width()
	var combined := player_half + _computed_half_width + teleport_gap
	return max(combined, 32.0)

func _player_half_width() -> float:
	if not _player_target:
		return 24.0
	var player_shape := _find_first_shape(_player_target)
	if player_shape:
		return _half_width_from_shape(player_shape)
	return 24.0

func _find_first_shape(node: Node) -> Shape2D:
	if node is CollisionShape2D and node.shape:
		return node.shape
	for child in node.get_children():
		var found := _find_first_shape(child)
		if found:
			return found
	return null

func _half_width_from_shape(shape: Shape2D) -> float:
	if shape is RectangleShape2D:
		return shape.size.x * 0.5
	if shape is CapsuleShape2D:
		return shape.radius
	if shape is CircleShape2D:
		return shape.radius
	return 16.0

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	super._on_hitbox_body_entered(body)

func update_animation() -> void:
	if not sprite:
		return
	if sprite_faces_right:
		sprite.flip_h = (direction == -1)
	else:
		sprite.flip_h = (direction == 1)
	if is_dead:
		sprite.play("death")
		return
	match _state:
		State.TELEPORT_OUT:
			sprite.play("teleport_out")
		State.TELEPORT_IN:
			sprite.play("teleport_in")
		State.ATTACK:
			sprite.play("attack")
		State.PATROL, State.COOLDOWN:
			if is_moving:
				sprite.play("walk")
			else:
				sprite.play("idle")
		_:
			sprite.play("idle")

func _on_animation_finished() -> void:
	var animation_name: StringName = sprite.animation if sprite else &""
	super._on_animation_finished()
	if animation_name.begins_with("attack"):
		attack_area.monitoring = false
		if _state == State.ATTACK:
			_enter_cooldown()
