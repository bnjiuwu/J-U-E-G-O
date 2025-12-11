extends EnemyGround

# --- ESTADOS ---
enum State { PATROL, PREPARE_ATTACK, MISSILE }
var current_state = State.PATROL

# --- CONFIGURACIÓN ---
@export_group("Ajustes Gude")
@export var patrol_speed: float = 50.0
@export var missile_speed: float = 450.0  # Velocidad de la embestida
@export var prepare_duration: float = 0.6
@export var warning_jump_force: float = 200.0
@export var rebound_push_speed: float = 220.0
@export var rebound_jump_force: float = 160.0
@export var rebound_duration: float = 0.35
@export var recover_duration: float = 1.0
@export var missile_max_duration: float = 2.5
@export var my_max_health: int = 120
@export var wall_flip_cooldown: float = 0.15

# --- REFERENCIAS ---
@onready var floor_detector: RayCast2D = get_node_or_null("FloorDetector")
@onready var wall_detector: RayCast2D = get_node_or_null("WallDetector")
@onready var detection_zone: Area2D = get_node_or_null("DetectionZone")
# NOTA: Asegúrate de conectar la señal body_entered del Hitbox en el editor
@onready var my_hitbox: Area2D = get_node_or_null("Hitbox") 

var _missile_elapsed: float = 0.0
var _is_showing_explosion: bool = false
var _is_recovering: bool = false
var _rebound_time_left: float = 0.0
var _last_attack_direction: int = 1
var _wall_flip_timer: float = 0.0

func _ready():
	max_health = my_max_health
	super._ready() 
	_last_attack_direction = direction
	
	# Asegurar que los ojos funcionen
	if floor_detector: floor_detector.enabled = true
	if wall_detector: wall_detector.enabled = true
	
	# Conectar visión automáticamente si existe
	if detection_zone:
		if not detection_zone.body_entered.is_connected(_on_vision_detect):
			detection_zone.body_entered.connect(_on_vision_detect)
		_set_detection_active(true)

	if my_hitbox:
		my_hitbox.monitoring = false

	velocity.x = direction * patrol_speed

func ground_behavior(delta: float) -> void:
	_wall_flip_timer = max(_wall_flip_timer - delta, 0.0)
	match current_state:
		State.PATROL:
			_state_patrol(delta)
		State.PREPARE_ATTACK:
			velocity.x = 0 
			# Aquí la gravedad normal del padre sigue aplicando
		State.MISSILE:
			_state_missile(delta)

# --- 1. PATRULLA (Gravedad normal) ---
func _state_patrol(delta):
	is_attacking = false 
	_missile_elapsed = 0.0

	if _rebound_time_left > 0.0:
		_rebound_time_left = max(_rebound_time_left - delta, 0.0)
		velocity.x = -_last_attack_direction * rebound_push_speed
		return

	if _is_showing_explosion:
		velocity.x = 0
		return

	velocity.x = direction * patrol_speed
	var should_flip := false

	if wall_detector and wall_detector.is_colliding():
		should_flip = true
	elif floor_detector and not floor_detector.is_colliding() and is_on_floor():
		should_flip = true
	elif is_on_wall() and _wall_flip_timer <= 0.0:
		should_flip = true

	if should_flip:
		flip_direction()
		_wall_flip_timer = wall_flip_cooldown

# --- 2. EMBESTIDA EN EL PISO ---
func _state_missile(delta):
	_missile_elapsed += delta
	velocity.x = direction * missile_speed

	# Si deja de tocar el piso o ya no hay suelo enfrente, cancelar ataque
	if not is_on_floor():
		stop_missile(false)
		return
	if floor_detector and not floor_detector.is_colliding():
		stop_missile(false)
		return

	# Si choca con pared rebota
	if wall_detector and wall_detector.is_colliding():
		stop_missile(true)
	elif missile_max_duration > 0.0 and _missile_elapsed >= missile_max_duration:
		stop_missile(false)

# --- SOBRESCRIBIR ANIMACIONES ---
# Esto es CLAVE: Sobrescribimos al padre para usar tu animación "ATTACK"
func update_animation() -> void:
	# Si estamos muertos, dejamos que el padre maneje la muerte
	if is_dead:
		super.update_animation()
		return

	if _is_showing_explosion:
		return

	if current_state == State.PREPARE_ATTACK:
		if sprite.animation != "attack":
			sprite.play("attack")
		return

	# Si estamos en modo MISIL, usamos la animación de esfera girando
	if current_state == State.MISSILE:
		if sprite.animation != "ATTACK":
			sprite.play("ATTACK")
	else:
		# Para el resto (caminar/idle), usamos la lógica normal del padre
		super.update_animation()

# --- SEÑALES Y COLISIONES ---

# Detección visual (Trigger del ataque)
func _on_vision_detect(body):
	if current_state != State.PATROL:
		return
	if _is_recovering:
		return
	if not body.is_in_group("player"):
		return
	if not is_on_floor():
		return
	_face_body(body)
	start_prepare()

# ¡IMPORTANTE! Conecta esto desde el nodo Hitbox -> body_entered
func _on_hitbox_body_entered(body):
	# Esta función detecta el choque FÍSICO con el jugador
	super._on_hitbox_body_entered(body)
	if current_state == State.MISSILE and body.is_in_group("player"):
		_handle_player_collision()

# --- GESTIÓN DE ESTADOS ---

func start_prepare():
	if current_state != State.PATROL:
		return
	current_state = State.PREPARE_ATTACK
	is_attacking = true
	velocity.x = 0
	velocity.y = -warning_jump_force # Saltito de aviso
	_set_detection_active(false)
	if my_hitbox:
		my_hitbox.monitoring = false
	var prepare_timer := get_tree().create_timer(prepare_duration)
	await prepare_timer.timeout
	if is_dead or current_state != State.PREPARE_ATTACK:
		return
	start_missile()

func start_missile():
	current_state = State.MISSILE
	is_attacking = true
	_last_attack_direction = direction
	_missile_elapsed = 0.0
	if my_hitbox:
		my_hitbox.monitoring = true
	velocity.y = 0
	velocity.x = direction * missile_speed

func stop_missile(apply_bounce: bool, reactivate_detection: bool = true, flip_after_bounce: bool = true):
	if current_state != State.MISSILE:
		return
	current_state = State.PATROL
	is_attacking = false
	_missile_elapsed = 0.0
	if my_hitbox:
		my_hitbox.monitoring = false
	if apply_bounce:
		_rebound_time_left = rebound_duration
		velocity.x = -_last_attack_direction * rebound_push_speed
		velocity.y = -rebound_jump_force
		if flip_after_bounce:
			flip_direction()
	else:
		_rebound_time_left = 0.0
		velocity.x = direction * patrol_speed
		velocity.y = 0
	if reactivate_detection and not _is_recovering:
		_set_detection_active(true)

func _face_body(body: Node2D) -> void:
	var delta := body.global_position.x - global_position.x
	if abs(delta) < 0.01:
		return
	var desired_direction := 1 if delta > 0 else -1
	if desired_direction != direction:
		flip_direction()

func _set_detection_active(active: bool) -> void:
	if not detection_zone:
		return
	detection_zone.set_deferred("monitoring", active)

func _play_explosion() -> void:
	if not sprite or _is_showing_explosion:
		return
	_is_showing_explosion = true
	_play_animation_sequence([&"Bum", &"Reload"], 0, Callable(self, "_on_explosion_sequence_finished"))

func _get_animation_duration(anim_name: StringName) -> float:
	if not sprite or not sprite.sprite_frames:
		return 0.0
	if not sprite.sprite_frames.has_animation(anim_name):
		return 0.0
	var frames := sprite.sprite_frames.get_frame_count(anim_name)
	var speed := sprite.sprite_frames.get_animation_speed(anim_name)
	if speed <= 0.0:
		return 0.0
	return frames / speed

func _play_animation_sequence(sequence: Array[StringName], index: int, on_complete: Callable = Callable()) -> void:
	if not sprite:
		_is_showing_explosion = false
		return
	if index >= sequence.size():
		if on_complete.is_valid():
			on_complete.call()
		else:
			_is_showing_explosion = false
			update_animation()
		return
	var anim_name := sequence[index]
	var duration := _play_animation_and_get_duration(anim_name)
	if duration <= 0.0:
		_play_animation_sequence(sequence, index + 1, on_complete)
		return
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func (): _play_animation_sequence(sequence, index + 1, on_complete))

func _play_animation_and_get_duration(anim_name: StringName) -> float:
	if not sprite or not sprite.sprite_frames:
		return 0.0
	if not sprite.sprite_frames.has_animation(anim_name):
		return 0.0
	sprite.play(anim_name)
	return _get_animation_duration(anim_name)

func flip_direction():
	super.flip_direction()
	if detection_zone:
		detection_zone.position.x *= -1

func _handle_player_collision() -> void:
	if _is_recovering:
		return
	_is_recovering = true
	_set_detection_active(false)
	stop_missile(true, false, false)
	_play_explosion()

func _on_explosion_sequence_finished() -> void:
	_is_showing_explosion = false
	update_animation()
	_begin_recovery_cooldown()

func _begin_recovery_cooldown() -> void:
	var timer := get_tree().create_timer(recover_duration)
	timer.timeout.connect(func ():
		if is_dead:
			return
		_is_recovering = false
		_set_detection_active(true)
	)
