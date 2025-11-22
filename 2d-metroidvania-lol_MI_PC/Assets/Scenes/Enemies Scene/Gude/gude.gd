extends EnemyGround

# --- ESTADOS ---
enum State { PATROL, PREPARE_ATTACK, ROLLING }
var current_state = State.PATROL

# --- CONFIGURACIÓN ---
@export_group("Ajustes Gude")
@export var patrol_speed: float = 50.0
@export var roll_speed: float = 350.0
@export var prepare_duration: float = 0.6
@export var my_max_health: int = 6

# --- REFERENCIAS ---
@onready var floor_detector: RayCast2D = get_node_or_null("FloorDetector")
@onready var wall_detector: RayCast2D = get_node_or_null("WallDetector")
@onready var detection_zone: Area2D = get_node_or_null("DetectionZone") # <--- Nueva referencia

func _ready():
	max_health = my_max_health 
	super._ready()
	
	# Seguridad para nombres de detectores de suelo/pared
	if not floor_detector: floor_detector = get_node_or_null("floor_check")
	if not wall_detector: wall_detector = get_node_or_null("wall_check")
	
	# Activar sensores de movimiento
	if floor_detector: floor_detector.enabled = true
	if wall_detector: wall_detector.enabled = true
	
	# --- CONEXIÓN AUTOMÁTICA DE LA ZONA ---
	if detection_zone:
		# Conectamos la señal por código para que no tengas que hacerlo manual
		if not detection_zone.body_entered.is_connected(_on_detection_zone_body_entered):
			detection_zone.body_entered.connect(_on_detection_zone_body_entered)
	else:
		print("ERROR: No encuentro el nodo 'DetectionZone' en el Gude")

	velocity.x = direction * patrol_speed

func ground_behavior(delta: float) -> void:
	match current_state:
		State.PATROL:
			_state_patrol(delta)
		State.PREPARE_ATTACK:
			_state_prepare(delta)
		State.ROLLING:
			_state_rolling(delta)

# --- FASE 1: PATRULLA ---
func _state_patrol(delta):
	velocity.x = direction * patrol_speed
	is_attacking = false
	
	# Movimiento seguro (Tipo Slime)
	if wall_detector and wall_detector.is_colliding():
		flip_direction()
	elif floor_detector and not floor_detector.is_colliding() and is_on_floor():
		flip_direction()
	
	# NOTA: Ya no hay "if player_detector" aquí. 
	# La detección ahora ocurre por la señal _on_detection_zone_body_entered abajo.

# --- FASE 2: PREPARACIÓN ---
func _state_prepare(delta):
	velocity.x = 0 # Se queda quieto

# --- FASE 3: EMBESTIDA ---
func _state_rolling(delta):
	velocity.x = direction * roll_speed
	is_attacking = true
	
	# Rebote contra pared
	if wall_detector and wall_detector.is_colliding():
		change_state(State.PATROL)
		flip_direction()

# --- SEÑAL DE DETECCIÓN (NUEVO) ---
func _on_detection_zone_body_entered(body):
	# Solo atacamos si estamos patrullando y detectamos al jugador
	if current_state == State.PATROL and body.is_in_group("player"):
		change_state(State.PREPARE_ATTACK)

# --- GESTIÓN DE ESTADOS ---
func change_state(new_state):
	current_state = new_state
	
	if new_state == State.PREPARE_ATTACK:
		velocity.y = -150 # Salto de aviso
		await get_tree().create_timer(prepare_duration).timeout
		if not is_dead:
			change_state(State.ROLLING)

# --- GIRAR ---
func flip_direction():
	super.flip_direction() # Gira sprite y RayCasts (gracias al padre)
	
	# MANUALMENTE giramos la DetectionZone porque el padre no sabe que existe
	if detection_zone:
		detection_zone.position.x *= -1
