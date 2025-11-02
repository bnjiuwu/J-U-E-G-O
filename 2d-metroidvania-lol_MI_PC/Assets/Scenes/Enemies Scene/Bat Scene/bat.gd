extends CharacterBody2D

# --- Propiedades ---
@export var patrol_speed: float = 50.0
@export var attack_speed: float = 130.0
@export var retreat_speed: float = 200.0      # 💨 MÁS RÁPIDO al retroceder
@export var retreat_duration: float = 0.6     # ⏱️ Tiempo de retroceso corto
@export var damage_amount: int = 20
@export var max_health: int = 3
@export var flip_cooldown: float = 0.45

var health: int
var _flip_lock := 0.0
var _retreat_timer := 0.0                    # ⏳ tiempo restante de retroceso

# --- Estados y Lógica ---
enum State { PATROL, ATTACK, RETREAT }
var current_state = State.PATROL
var player_target: CharacterBody2D = null
var direction: int = 1 # 1 derecha, -1 izquierda

# --- Referencias a Nodos ---
var sprite: AnimatedSprite2D = null
@onready var wall_check: RayCast2D = $WallCheck
@onready var detection_zone: Area2D = $DetectionZone

func _ready():
	health = max_health

	sprite = get_node_or_null("animated") as AnimatedSprite2D
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("fly2"):
		sprite.play("fly2")

	if wall_check:
		wall_check.enabled = true

func _physics_process(delta):
	_flip_lock = max(_flip_lock - delta, 0.0)

	match current_state:
		State.PATROL:
			patrol_movement()
		State.ATTACK:
			attack_movement()
		State.RETREAT:
			retreat_movement(delta)

	if sprite:
		sprite.flip_h = (direction == -1)

	move_and_slide()

# --- Movimientos ---
func patrol_movement():
	velocity.x = direction * patrol_speed
	velocity.y = 0.0

	if wall_check and wall_check.is_colliding() and _flip_lock <= 0.0:
		_flip()

func attack_movement():
	if not player_target:
		current_state = State.PATROL
		return

	var dir_vec := global_position.direction_to(player_target.global_position)
	velocity = dir_vec * attack_speed

	if velocity.x > 0.0:
		direction = 1
	elif velocity.x < 0.0:
		direction = -1

# --- Nuevo movimiento de retroceso ---
func retreat_movement(delta: float):
	_retreat_timer -= delta
	if not player_target:
		current_state = State.PATROL
		return

	var away_vec := global_position.direction_to(player_target.global_position) * -1
	velocity = away_vec * retreat_speed

	if _retreat_timer <= 0.0:
		current_state = State.ATTACK  # vuelve a atacar tras retroceder

# --- Flip ---
func _flip():
	direction *= -1
	_flip_lock = flip_cooldown

	if wall_check:
		wall_check.enabled = false
		wall_check.position.x *= -1
		wall_check.target_position.x *= -1
		call_deferred("_re_enable_wallcheck")

func _re_enable_wallcheck():
	if wall_check:
		wall_check.enabled = true

# --- Daño y muerte ---
func take_damage(amount: int):
	health -= amount
	if health <= 0:
		queue_free()

# --- Señales DetectionZone ---
func _on_detection_zone_body_entered(body: Node):
	if body.is_in_group("player"):
		player_target = body
		current_state = State.ATTACK

func _on_detection_zone_body_exited(body: Node):
	if body == player_target:
		player_target = null
		current_state = State.PATROL

# --- Llamar RETREAT luego de atacar ---
func on_attack_hit_player():
	# cuando daña al jugador, activa el retroceso
	_retreat_timer = retreat_duration
	current_state = State.RETREAT
