extends CharacterBody2D

# GOLEM ENEMY IMPLEMENTATION
# Comportamiento: patrulla lenta, detecta jugador cerca, lanza una roca (proyectil) tras cargar
# Animaciones esperadas: idle, walk, throw (se derivan de hojas de sprites: idle Golem.png, walk golem.png, throw golem.png)

enum State { IDLE, WALK, WINDUP, THROW, RECOVER }

@export var idle_texture: Texture2D
@export var walk_texture: Texture2D
@export var throw_texture: Texture2D
@export var sheet_columns: int = 4
@export var sheet_rows: int = 4
@export var idle_frames: int = 4
@export var walk_frames: int = 6
@export var throw_frames: int = 6
@export var animation_speed: float = 6.0

@export var patrol_speed: float = 50.0
@export var gravity: float = 900.0
@export var wander_time_min: float = 1.5
@export var wander_time_max: float = 3.5
@export var throw_distance: float = 420.0
@export var windup_time: float = 0.8
@export var recover_time: float = 0.6
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 320.0
@export var max_health: int = 60
@export var contact_damage: int = 10

var _state: State = State.IDLE
var _direction: int = 1
var _state_time: float = 0.0
var _target: Node = null
var _health: int
var _timer_wander: float = 0.0

@onready var _sprite: AnimatedSprite2D = $Sprite if has_node("Sprite") else null
@onready var _detection: Area2D = $DetectionZone if has_node("DetectionZone") else null
@onready var _hitbox: Area2D = $Hitbox if has_node("Hitbox") else null
@onready var _floor_raycast: RayCast2D = $FloorCheck if has_node("FloorCheck") else null
@onready var _wall_raycast: RayCast2D = $WallCheck if has_node("WallCheck") else null

func _ready():
	_health = max_health
	_build_frames()
	_enter_state(State.IDLE)
	if _detection:
		_detection.body_entered.connect(_on_detection_body_entered)
		_detection.body_exited.connect(_on_detection_body_exited)
	if _hitbox:
		_hitbox.body_entered.connect(_on_hitbox_body_entered)

func _physics_process(delta: float) -> void:
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
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = min(velocity.y, 0)

func _process_idle(delta: float) -> void:
	if _target and _can_throw_at_target():
		_enter_state(State.WINDUP)
		return
	_timer_wander -= delta
	if _timer_wander <= 0.0:
		_direction = (randf() < 0.5) ? -1 : 1
		_enter_state(State.WALK)

func _process_walk(delta: float) -> void:
	if _target and _can_throw_at_target():
		_enter_state(State.WINDUP)
		return
	velocity.x = _direction * patrol_speed
	_handle_flip()
	if _wall_raycast and _wall_raycast.is_colliding():
		_direction *= -1
	if _floor_raycast and not _floor_raycast.is_colliding():
		_direction *= -1
	if _state_time >= _timer_wander:
		_enter_state(State.IDLE)
		velocity.x = 0

func _process_throw() -> void:
	# Lanzar proyectil una única vez al entrar en THROW
	_spawn_projectile()
	_enter_state(State.RECOVER)

func _spawn_projectile() -> void:
	if not projectile_scene or not _target:
		return
	var proj = projectile_scene.instantiate()
	if proj and proj.has_method("initialize"):
		var dir = (_target.global_position - global_position).normalized()
		proj.global_position = global_position + Vector2(sign(dir.x)*20, -10)
		proj.initialize(dir * projectile_speed, contact_damage)
	get_tree().current_scene.add_child(proj)

func _can_throw_at_target() -> bool:
	if not _target: return false
	var dist = global_position.distance_to(_target.global_position)
	return dist <= throw_distance and is_on_floor()

func _enter_state(new_state: State) -> void:
	_state = new_state
	_state_time = 0.0
	match _state:
		State.IDLE:
			velocity.x = 0
			_timer_wander = randf_range(wander_time_min, wander_time_max)
			_play_anim("idle")
		State.WALK:
			_play_anim("walk")
		State.WINDUP:
			velocity.x = 0
			_face_target()
			_play_anim("throw", false)
		State.THROW:
			_play_anim("throw", false)
		State.RECOVER:
			_play_anim("idle")

func _play_anim(name: String, loop: bool = true) -> void:
	if _sprite:
		if _sprite.sprite_frames.has_animation(name):
			_sprite.animation = name
			_sprite.play()
			# Godot 4 no expone `loop` directo en AnimatedSprite2D; usar SpriteFrames
			if _sprite.sprite_frames:
				_sprite.sprite_frames.set_animation_loop(name, loop)

func _handle_flip() -> void:
	if _sprite:
		_sprite.flip_h = _direction < 0
	if _floor_raycast:
		_floor_raycast.position.x = 18 * _direction
	if _wall_raycast:
		_wall_raycast.position.x = 20 * _direction
		_wall_raycast.target_position.x = 24 * _direction

func _face_target() -> void:
	if _target:
		_direction = -1 if _target.global_position.x < global_position.x else 1
		_handle_flip()

func take_damage(amount: int) -> void:
	_health -= amount
	if _health <= 0:
		queue_free()

func _on_detection_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_target = body

func _on_detection_body_exited(body: Node) -> void:
	if body == _target:
		_target = null
		if _state in [State.WINDUP, State.THROW]:
			_enter_state(State.IDLE)

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)

func _build_frames() -> void:
	if not _sprite:
		return
	var frames = SpriteFrames.new()
	_add_sheet_animation(frames, "idle", idle_texture, idle_frames, true)
	_add_sheet_animation(frames, "walk", walk_texture, walk_frames, true)
	_add_sheet_animation(frames, "throw", throw_texture, throw_frames, false)
	_sprite.sprite_frames = frames
	_sprite.animation = "idle"

func _add_sheet_animation(frames: SpriteFrames, name: String, texture: Texture2D, frame_count: int, loop: bool) -> void:
	if not texture:
		return
	frames.add_animation(name)
	frames.set_animation_loop(name, loop)
	frames.set_animation_speed(name, animation_speed)
	var w = texture.get_width() / sheet_columns
	var h = texture.get_height() / sheet_rows
	var max_possible = sheet_columns * sheet_rows
	frame_count = clamp(frame_count, 1, max_possible)
	for i in range(frame_count):
		var col = i % sheet_columns
		var row = i / sheet_columns
		var region = Rect2(col * w, row * h, w, h)
		var atlas = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		frames.add_frame(name, atlas)

func randf_range(a: float, b: float) -> float:
	return randf() * (b - a) + a
