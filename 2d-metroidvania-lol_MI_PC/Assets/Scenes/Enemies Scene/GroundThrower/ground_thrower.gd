extends EnemyGround
class_name GroundThrower

@export var speed: float = 40.0
@export var attack_range: float = 800.0
@export var fire_rate: float = 0.7
@export var projectile_scene: PackedScene

@onready var floor_check: RayCast2D = $FloorCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var detection_zone: Area2D = $DetectionZone
@onready var spawn_point: Node2D = $ProjectileSpawnPoint
@onready var fire_cooldown: Timer = $FireCooldown

var player_target: CharacterBody2D = null
var can_fire: bool = true


func _ready() -> void:
	# Muy importante: inicializa Enemy (vida, grupos, hitbox, barra, etc.)
	super._ready()

	# Timer de disparo
	fire_cooldown.one_shot = true
	if not fire_cooldown.timeout.is_connected(_on_fire_cooldown_timeout):
		fire_cooldown.timeout.connect(_on_fire_cooldown_timeout)

	# Zona de detección
	if detection_zone:
		if not detection_zone.body_entered.is_connected(_on_detection_zone_body_entered):
			detection_zone.body_entered.connect(_on_detection_zone_body_entered)
		if not detection_zone.body_exited.is_connected(_on_detection_zone_body_exited):
			detection_zone.body_exited.connect(_on_detection_zone_body_exited)


# ============================================================
#   LÓGICA DE ENEMIGO TERRESTRE
#   (EnemyGround llamará ground_behavior(delta))
# ============================================================
func ground_behavior(delta: float) -> void:
	if player_target:
		attack_behavior()
	else:
		patrol_behavior()

	_update_directional_nodes()

# ============================================================
#   PATRULLA
# ============================================================
func patrol_behavior() -> void:
	velocity.x = direction * speed

	# Choca con pared → darse vuelta
	if wall_check and wall_check.is_colliding():
		flip_direction()

	# Llega al borde de la plataforma → darse vuelta
	if floor_check and is_on_floor() and not floor_check.is_colliding():
		flip_direction()

	is_attacking = false
	# is_moving lo setea EnemyGround según velocity.x


# ============================================================
#   ATAQUE
# ============================================================
func attack_behavior() -> void:
	if not player_target:
		return

	var to_player := player_target.global_position - global_position
	var dist := to_player.length()

	# mirar al jugador
	direction = 1 if to_player.x > 0.0 else -1

	if dist > attack_range:
		# demasiado lejos → moverse hacia él
		velocity.x = direction * speed
		is_attacking = false
	else:
		# en rango → parar y lanzar proyectil
		velocity.x = 0

		if can_fire:
			is_attacking = true
			can_fire = false
			_fire_parabolic_shot()
			fire_cooldown.start(fire_rate)


func _fire_parabolic_shot() -> void:
	if not projectile_scene:
		return
	if not player_target:
		return
	if not spawn_point:
		return

	var proj = projectile_scene.instantiate()
	proj.global_position = spawn_point.global_position

	# configurar parábola hacia la posición actual del jugador
	if proj.has_method("setup_parabola"):
		proj.setup_parabola(player_target.global_position)

	get_tree().current_scene.add_child(proj)

func _update_directional_nodes() -> void:
	var s :float= sign(direction)

	# Raycast de pared
	if wall_check:
		wall_check.position.x = s * abs(wall_check.position.x)
		wall_check.target_position.x = s * abs(wall_check.target_position.x)

	# Raycast de piso
	if floor_check:
		floor_check.position.x = s * abs(floor_check.position.x)
		# si FloorCheck también usa target_position:
		if floor_check.target_position.x != 0.0:
			floor_check.target_position.x = s * abs(floor_check.target_position.x)

	# Punto de disparo
	if spawn_point:
		spawn_point.position.x = s * abs(spawn_point.position.x)

	# Zona de detección
	if detection_zone:
		detection_zone.position.x = s * abs(detection_zone.position.x)
		var shape := detection_zone.get_node_or_null("CollisionShape2D")
		if shape:
			shape.position.x = s * abs(shape.position.x)




func _on_fire_cooldown_timeout() -> void:
	can_fire = true
	is_attacking = false

# ============================================================
#   DETECCIÓN
# ============================================================
func _on_detection_zone_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_target = body
		print("[Thrower] Jugador detectado")


func _on_detection_zone_body_exited(body: Node) -> void:
	if body == player_target:
		player_target = null
		is_attacking = false
		print("[Thrower] Jugador fuera de rango")
