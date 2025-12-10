extends Enemy
class_name MagicBook

@export var patrol_speed: float = 55.0
@export var float_height: float = 52.0
@export var height_lerp_speed: float = 6.0
@export var hover_amplitude: float = 8.0
@export var hover_frequency: float = 3.0
@export var cast_duration: float = 1.0
@export var finish_duration: float = 0.7
@export var attack_cooldown: float = 2.5
@export var pencil_rain_scene: PackedScene
@export var pencil_spawn_offset: Vector2 = Vector2(0.0, -140.0)
@export var pencil_damage: int = 20
@export var channel_animation: StringName = &"attack_continue"

@onready var floor_check: RayCast2D = $Sensors/FloorCheck
@onready var edge_check: RayCast2D = $Sensors/EdgeCheck
@onready var wall_check: RayCast2D = $Sensors/WallCheck
@onready var detection_zone: Area2D = $DetectionZone
@onready var cast_timer: Timer = $Timers/CastTimer
@onready var finish_timer: Timer = $Timers/FinishTimer
@onready var cooldown_timer: Timer = $Timers/CooldownTimer

enum State { PATROL, CASTING, FINISHING, CHANNELING, COOLDOWN }
var _state: State = State.PATROL
var _hover_time: float = 0.0
var _attack_position: Vector2 = Vector2.ZERO
var _player_target: CharacterBody2D = null
var _preferred_height: float = 0.0
var _player_in_zone: bool = false

func _ready() -> void:
	super._ready()
	_preferred_height = global_position.y
	if detection_zone:
		detection_zone.body_entered.connect(_on_detection_zone_body_entered)
		detection_zone.body_exited.connect(_on_detection_zone_body_exited)
	cast_timer.one_shot = true
	finish_timer.one_shot = true
	cooldown_timer.one_shot = true
	cast_timer.timeout.connect(_on_cast_timer_timeout)
	finish_timer.timeout.connect(_on_finish_timer_timeout)
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	_update_directional_nodes()
	if not pencil_rain_scene:
		var default_scene_path := "res://Assets/Scenes/Enemies Scene/Magic book/PencilRain.tscn"
		if ResourceLoader.exists(default_scene_path):
			pencil_rain_scene = load(default_scene_path)

func enemy_behavior(delta: float) -> void:
	if is_dead:
		return

	_hover_time += delta * hover_frequency
	_maintain_height(delta)

	match _state:
		State.PATROL:
			_patrol_behavior()
		State.CASTING:
			_casting_behavior()
		State.FINISHING:
			_finishing_behavior()
		State.CHANNELING:
			_channeling_behavior()
		State.COOLDOWN:
			_cooldown_behavior()

	move_and_slide()

func _maintain_height(delta: float) -> void:
	if floor_check and floor_check.is_colliding():
		_preferred_height = floor_check.get_collision_point().y - float_height
	var desired_y := _preferred_height + sin(_hover_time) * hover_amplitude
	var error := desired_y - global_position.y
	velocity.y = lerp(velocity.y, error * height_lerp_speed, 5.0 * delta)

func _patrol_behavior() -> void:
	velocity.x = direction * patrol_speed
	is_moving = true
	is_attacking = false
	_check_direction_changes()

func _casting_behavior() -> void:
	velocity.x = 0
	is_moving = false
	is_attacking = true

func _finishing_behavior() -> void:
	velocity.x = 0
	is_moving = false
	is_attacking = true

func _channeling_behavior() -> void:
	velocity = Vector2.ZERO
	is_moving = false
	is_attacking = true

func _cooldown_behavior() -> void:
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

func _begin_cast_sequence() -> void:
	if _state == State.CASTING:
		return
	_state = State.CASTING
	_refresh_attack_position()
	cooldown_timer.stop()
	velocity = Vector2.ZERO
	is_attacking = true
	is_moving = false
	cast_timer.start(cast_duration)

func _on_cast_timer_timeout() -> void:
	_refresh_attack_position()
	_trigger_pencil_rain()
	if _player_in_zone:
		_enter_channeling_state()
	else:
		_start_finish_phase()

func _on_finish_timer_timeout() -> void:
	_state = State.COOLDOWN
	is_attacking = false
	cooldown_timer.start(attack_cooldown)

func _on_cooldown_timer_timeout() -> void:
	if _state == State.CHANNELING:
		if _player_in_zone:
			_refresh_attack_position()
			_trigger_pencil_rain()
			cooldown_timer.start(attack_cooldown)
		else:
			_exit_channeling_state()
		return
	_state = State.PATROL
	if _player_in_zone:
		_try_start_attack()

func _trigger_pencil_rain() -> void:
	if not pencil_rain_scene:
		return
	var rain_instance := pencil_rain_scene.instantiate()
	var spawn_position := Vector2(
		_attack_position.x + pencil_spawn_offset.x,
		_attack_position.y + pencil_spawn_offset.y
	)
	if rain_instance is Node2D:
		rain_instance.global_position = spawn_position
	if "damage" in rain_instance:
		rain_instance.damage = pencil_damage
	if rain_instance.has_method("set_damage"):
		rain_instance.set_damage(pencil_damage)
	get_tree().current_scene.add_child(rain_instance)

func _on_detection_zone_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_target = body
	_player_in_zone = true
	if _state in [State.PATROL, State.COOLDOWN]:
		_try_start_attack()

func _on_detection_zone_body_exited(body: Node) -> void:
	if body == _player_target:
		_player_target = null
		_player_in_zone = false
		_exit_channeling_state()

func _flip_direction() -> void:
	direction *= -1
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
		floor_check.target_position.x = s * abs(floor_check.target_position.x)
	if detection_zone:
		detection_zone.position.x = s * abs(detection_zone.position.x)
		var shape := detection_zone.get_node_or_null("CollisionShape2D")
		if shape:
			shape.position.x = s * abs(shape.position.x)

func update_animation() -> void:
	if not sprite:
		return

	if is_dead:
		sprite.play("death")
		return
	sprite.flip_h = (direction == -1)

	match _state:
		State.CASTING:
			sprite.play("attack")
		State.FINISHING:
			sprite.play("attack_finish")
		State.CHANNELING:
			var loop_anim := channel_animation
			if not sprite.sprite_frames or not sprite.sprite_frames.has_animation(loop_anim):
				loop_anim = "attack"
			sprite.play(loop_anim)
			return
		_:
			sprite.play("idle")

func _try_start_attack() -> void:
	if _state in [State.CASTING, State.FINISHING, State.CHANNELING]:
		return
	if not _player_in_zone:
		return
	if not cooldown_timer.is_stopped():
		return
	if not _player_target or not is_instance_valid(_player_target):
		return
	_refresh_attack_position()
	_begin_cast_sequence()

func _refresh_attack_position() -> void:
	if _player_target and is_instance_valid(_player_target):
		_attack_position = _player_target.global_position

func _enter_channeling_state() -> void:
	if _state == State.CHANNELING:
		return
	_state = State.CHANNELING
	velocity = Vector2.ZERO
	is_moving = false
	is_attacking = true
	cooldown_timer.stop()
	cooldown_timer.start(attack_cooldown)

func _exit_channeling_state() -> void:
	if _state != State.CHANNELING:
		return
	_start_finish_phase()

func _start_finish_phase() -> void:
	if _state == State.FINISHING:
		return
	_state = State.FINISHING
	is_attacking = true
	is_moving = false
	velocity = Vector2.ZERO
	cooldown_timer.stop()
	finish_timer.stop()
	finish_timer.start(finish_duration)
