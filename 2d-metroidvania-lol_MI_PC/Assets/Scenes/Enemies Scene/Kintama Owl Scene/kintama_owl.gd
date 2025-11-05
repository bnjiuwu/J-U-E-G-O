extends CharacterBody2D

enum State { IDLE, PATROL, ATTACK }

@export var idle_texture: Texture2D
@export var walk_texture: Texture2D
@export var fly_texture: Texture2D

@export_range(1, 16, 1) var idle_frames: int = 4
@export_range(1, 16, 1) var walk_frames: int = 4
@export_range(1, 16, 1) var fly_frames: int = 4

const FRAME_W: int = 128
const FRAME_H: int = 128

# Longitudes
const WALL_LEN: float = 24.0
const FLOOR_AHEAD_X: float = 18.0
const FLOOR_DOWN_Y: float = 26.0

@export var idle_wait_range: Vector2 = Vector2(1.2, 2.0)
@export var walk_speed: float = 55.0
@export var fly_speed: float = 160.0
@export var attack_duration: float = 1.6
@export var attack_cooldown: float = 1.2
@export var max_health: int = 120
@export var contact_damage: int = 15

var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var health: int
var state: State = State.IDLE
var idle_timer: float = 0.0
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var direction: int = -1
var player: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var floor_check: RayCast2D = $FloorCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var detection_area: Area2D = $DetectionZone
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	health = max_health
	idle_timer = randf_range(idle_wait_range.x, idle_wait_range.y)
	add_to_group("enemy")

	# Raycasts: evita auto-colisión y limita a capa 1 (mundo)
	for ray in [floor_check, wall_check]:
		if ray == null: continue
		ray.enabled = true
		ray.exclude_parent = true
		for i in range(1, 33):
			ray.set_collision_mask_value(i, false)
		ray.set_collision_mask_value(1, true) # asumiendo TileMap/World en capa 1

	# Hitbox: que NO detecte "mundo"
	if hitbox:
		for i in range(1, 33):
			hitbox.set_collision_mask_value(i, false)
		# ejemplo: 3 jugador, 4 proyectiles (ajusta a tu proyecto)
		hitbox.set_collision_mask_value(3, true)
		hitbox.set_collision_mask_value(4, true)

	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	hitbox.body_entered.connect(_on_hitbox_body_entered)

	_build_sprite_frames()
	sprite.play("fly")

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	match state:
		State.IDLE:
			_apply_ground_physics(delta)
			idle_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, walk_speed * delta * 2.0)
			if idle_timer <= 0.0:
				_enter_patrol()

		State.PATROL:
			_apply_ground_physics(delta)
			velocity.x = direction * walk_speed
			if floor_check and not floor_check.is_colliding():
				_flip_direction()
			elif wall_check and wall_check.is_colliding():
				_flip_direction()

		State.ATTACK:
			attack_timer -= delta
			if not is_instance_valid(player):
				player = null
			if attack_timer <= 0.0 or player == null:
				_enter_idle()
			else:
				var dir_vec := (player.global_position - global_position).normalized()
				velocity = dir_vec * fly_speed
				sprite.flip_h = dir_vec.x < 0

	if player and state != State.ATTACK and cooldown_timer <= 0.0:
		_enter_attack()

	_update_directional_nodes()
	move_and_slide()

func _apply_ground_physics(delta: float) -> void:
	velocity.y += gravity * delta

func _update_directional_nodes() -> void:
	# Sprite
	if state != State.ATTACK:
		sprite.flip_h = direction < 0

	# FLOOR ray: mueve el origen hacia delante y lanza solo hacia abajo
	# RayCast2D lanza de (0,0) a target_position (local al RayCast)
	if floor_check:
		floor_check.position = Vector2(direction * FLOOR_AHEAD_X, 0.0)
		floor_check.target_position = Vector2(0.0, FLOOR_DOWN_Y)

	# WALL ray: origen centrado; solo lanza hacia adelante
	if wall_check:
		wall_check.position = Vector2.ZERO
		wall_check.target_position = Vector2(direction * WALL_LEN, 0.0)

func _flip_direction() -> void:
	direction *= -1

func _enter_idle() -> void:
	state = State.IDLE
	idle_timer = randf_range(idle_wait_range.x, idle_wait_range.y)
	sprite.play("idle")
	attack_timer = 0.0

func _enter_patrol() -> void:
	state = State.PATROL
	sprite.play("walk")

func _enter_attack() -> void:
	if not is_instance_valid(player):
		return
	state = State.ATTACK
	attack_timer = attack_duration
	cooldown_timer = attack_cooldown
	direction = -1 if player.global_position.x < global_position.x else 1
	sprite.play("fly")

func _on_detection_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body
		if state != State.ATTACK:
			_enter_attack()

func _on_detection_body_exited(body: Node) -> void:
	if body == player:
		player = null

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile") or area.is_in_group("Skills"):
		if area.has_variable("damage"):
			take_damage(area.damage)
		area.queue_free()

func _on_hitbox_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health -= amount
	if health <= 0:
		_die()
	else:
		_enter_attack()

func _die() -> void:
	queue_free()

func _build_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	sprite.sprite_frames = frames
	_add_sheet_animation(frames, "fly",  fly_texture,  fly_frames,  true, 8.0)
	_add_sheet_animation(frames, "walk", walk_texture, walk_frames, true, 10.0)
	_add_sheet_animation(frames, "idle", idle_texture, idle_frames, true, 6.0)

func _add_sheet_animation(
	frames: SpriteFrames,
	state_name: String,
	texture: Texture2D,
	frame_count: int,
	loop: bool,
	speed: float
) -> void:
	if texture == null or frame_count <= 0:
		return

	var tex_w: int = texture.get_width()
	var tex_h: int = texture.get_height()

	var cols: int = tex_w / FRAME_W
	var rows: int = tex_h / FRAME_H
	var max_frames: int = cols * rows
	frame_count = min(frame_count, max_frames)

	if frames.has_animation(state_name):
		frames.clear_animation(state_name)
	else:
		frames.add_animation(state_name)

	frames.set_animation_loop(state_name, loop)
	frames.set_animation_speed(state_name, speed)

	for i in range(frame_count):
		var col: int = i % cols
		var row: int = int(i / cols)
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2i(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
		atlas.filter_clip = true
		frames.add_frame(state_name, atlas)
