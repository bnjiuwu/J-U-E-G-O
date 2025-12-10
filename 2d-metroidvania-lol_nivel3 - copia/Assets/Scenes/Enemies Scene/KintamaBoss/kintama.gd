extends BossEnemy
class_name BossKintama

# --- Estados de Movimiento ---
enum State { IDLE, PATROL, STALK, DIVE }

# --- Constantes de Capa y Detección ---
const LAYER_WORLD := 1
const LAYER_PLAYER := 3

# --- Configuración de RayCasts ---
const WALL_LEN: float = 32.0
const WALL_CHECK_OFFSET_X: float = 20.0
const WALL_CHECK_OFFSET_Y: float = -4.0
const FLOOR_AHEAD_X: float = 18.0
const FLOOR_DOWN_Y: float = 32.0
const FLOOR_CHECK_Y: float = 24.0

# --- Atributos de Movimiento ---
@export var idle_wait_range: Vector2 = Vector2(1.2, 2.0)
@export var walk_speed: float = 55.0     # velocidad caminando
@export var fly_speed: float = 90.0      # velocidad base volando (acecho)
@export var attack_duration: float = 0.8 # duración de la carga (DIVE)
@export var attack_cooldown: float = 1.5 # tiempo entre cargas (STALK → DIVE)
@export var contact_damage: int = 20

var enraged: bool = false

# Altura de acecho sobre el jugador
@export var stalk_height: float = -200
@export var stalk_side_distance: float = 80.0 

@export var stalk_side_change_interval: float = 2.5  # cada cuántos segundos PUEDE cambiar de lado

@export_range(0.0,1.0) var stalk_side_flip_chance: float = 0.5    

var stalk_side: int = 1          # -1 = izquierda del jugador, 1 = derecha
var stalk_side_timer: float = 0.0


# --- Detección del Jugador ---
@export var player_path: NodePath
@export var detection_radius: float = 300.0 # Fallback por distancia (opcional)

# --- Variables Internas ---
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var state: State = State.IDLE
var idle_timer: float = 0.0
var attack_timer: float = 0.0       # usado como temporizador de DIVE
var cooldown_timer: float = 0.0     # usado como temporizador entre cargas (STALK)
var player: CharacterBody2D = null
var dive_direction: Vector2 = Vector2.ZERO

@onready var floor_check: RayCast2D = $FloorCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var detection_area: Area2D = $DetectionZone


func _ready() -> void:
	super._ready() # Enemy._ready (vida, hitbox, barra, etc.)

	idle_timer = randf_range(idle_wait_range.x, idle_wait_range.y)
	_refresh_player_ref_from_path()

	# Configurar Raycasts (mundo)
	for ray in [floor_check, wall_check]:
		if ray == null:
			continue
		ray.enabled = true
		ray.exclude_parent = true
		ray.collide_with_areas = false
		ray.collide_with_bodies = true
		ray.set_collision_mask_value(LAYER_WORLD, true)

	# DetectionZone (jugador)
	if detection_area:
		detection_area.set_collision_mask_value(LAYER_PLAYER, true)
		# Conectar en el editor:
		#  - body_entered → _on_detection_zone_body_entered
		#  - body_exited  → _on_detection_zone_body_exited

	_update_directional_nodes()


# ============================================================
#   LÓGICA PRINCIPAL (Enemy llama enemy_behavior(delta))
# ============================================================
func enemy_behavior(delta: float) -> void:
	# cooldown entre cargas (se usa en STALK)
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	# Asegurar referencia al jugador
	if not is_instance_valid(player):
		_refresh_player_ref_from_path()
		if not is_instance_valid(player) and detection_radius > 0.0:
			_refresh_player_ref_from_group()

	# Fallback por distancia: si está cerca y aún en modo suelo → comenzar acecho
	if is_instance_valid(player) \
	and state in [State.IDLE, State.PATROL] \
	and cooldown_timer <= 0.0 \
	and detection_radius > 0.0:
		var dist := global_position.distance_to(player.global_position)
		if dist <= detection_radius:
			_enter_stalk()

	match state:
		State.IDLE:
			_state_idle(delta)

		State.PATROL:
			_state_patrol(delta)

		State.STALK:
			_state_stalk(delta)

		State.DIVE:
			_state_dive(delta)

	move_and_slide()
	_update_directional_nodes()


# ============================================================
#   ESTADOS
# ============================================================

func _state_idle(delta: float) -> void:
	_apply_ground_physics(delta)
	idle_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, walk_speed * delta * 2.0)

	if idle_timer <= 0.0:
		_enter_patrol()


func _state_patrol(delta: float) -> void:
	_apply_ground_physics(delta)

	velocity.x = direction * walk_speed

	# cambiar de sentido al borde / pared
	if (floor_check and not floor_check.is_colliding()) \
	or (wall_check and wall_check.is_colliding()) \
	or is_on_wall():
		flip()        # BossEnemy.flip() (cambia dir + sprite)
		_enter_idle() # pausa breve

	# si tenemos jugador válido y detection_zone lo vio, la señal lo hará entrar a STALK

func _state_stalk(delta: float) -> void:
	# si perdimos al jugador → volver a patrulla
	if not is_instance_valid(player):
		_enter_patrol()
		return

	# ==========================
	#   CAMBIO DE LADO ALEATORIO
	# ==========================
	stalk_side_timer -= delta
	if stalk_side_timer <= 0.0:
		stalk_side_timer = stalk_side_change_interval
		if randf() <= stalk_side_flip_chance:
			stalk_side *= -1
			print("[Kintama] cambia lado de acecho →", stalk_side)

	# ==========================
	#   POSICIÓN OBJETIVO DE ACECHO
	# ==========================
	var target_x := player.global_position.x + float(stalk_side) * stalk_side_distance
	var target_y := player.global_position.y + stalk_height
	var target_pos := Vector2(target_x, target_y)

	var to_target := target_pos - global_position

	if to_target.length() > 5.0:
		var dir := to_target.normalized()
		velocity = dir * fly_speed

		# actualizar dirección visual según el movimiento horizontal
		if abs(dir.x) > 0.1:
			direction = 1 if dir.x > 0.0 else -1
	else:
		velocity = Vector2.ZERO

	# animación de vuelo
	if sprite and sprite.animation != "fly":
		sprite.play("fly")

	# cuando el cooldown llega a 0 → entra en DIVE (carga)
	if cooldown_timer <= 0.0:
		_enter_dive()


func _state_dive(delta: float) -> void:
	# si perdimos al jugador durante la carga → terminar y volver a patrulla
	if not is_instance_valid(player):
		_enter_patrol()
		return

	attack_timer -= delta
	velocity = dive_direction * fly_speed * 2.0  # puedes ajustar el *2.0 a gusto

	if attack_timer <= 0.0:
		# carga terminada → volver a acechar
		_enter_stalk()


# ============================================================
#   TRANSICIONES
# ============================================================

func _enter_idle() -> void:
	state = State.IDLE
	idle_timer = randf_range(idle_wait_range.x, idle_wait_range.y)
	attack_timer = 0.0
	velocity.x = 0.0
	if sprite:
		sprite.play("idle")


func _enter_patrol() -> void:
	state = State.PATROL
	if sprite:
		sprite.play("walk")

func _enter_stalk() -> void:
	if not is_instance_valid(player):
		_enter_patrol()
		return

	state = State.STALK
	cooldown_timer = attack_cooldown  # tiempo hasta la PRIMER carga

	# 👇 definir de qué lado empieza a acechar (izq o der del jugador)
	stalk_side = 1 if global_position.x >= player.global_position.x else -1
	stalk_side_timer = stalk_side_change_interval

	if sprite:
		sprite.play("fly")

func _enter_dive() -> void:
	if not is_instance_valid(player):
		_enter_patrol()
		return

	state = State.DIVE
	attack_timer = attack_duration

	# dirección de la carga guardada
	dive_direction = (player.global_position - global_position).normalized()
	if abs(dive_direction.x) > 0.1:
		direction = 1 if dive_direction.x > 0.0 else -1

	if sprite:
		sprite.play("fly") # o una anim "charge" si la tienes


# ============================================================
#   FÍSICA EN SUELO
# ============================================================
func _apply_ground_physics(delta: float) -> void:
	if is_on_floor():
		velocity.y = min(velocity.y, 0.0)
	else:
		velocity.y += gravity * delta


# ============================================================
#   DIRECCIÓN / RAYCASTS
# ============================================================
func _update_directional_nodes() -> void:
	if floor_check:
		floor_check.position = Vector2(direction * FLOOR_AHEAD_X, FLOOR_CHECK_Y)
		floor_check.target_position = Vector2(0.0, FLOOR_DOWN_Y)
		floor_check.force_raycast_update()

	if wall_check:
		wall_check.position = Vector2(direction * WALL_CHECK_OFFSET_X, WALL_CHECK_OFFSET_Y)
		wall_check.target_position = Vector2(direction * WALL_LEN, WALL_CHECK_OFFSET_Y)
		wall_check.force_raycast_update()


# ============================================================
#   DETECCIÓN DEL JUGADOR (Area2D)
# ============================================================
func _on_detection_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as CharacterBody2D
		# apenas lo detecta, pasa del suelo a acechar desde el aire
		if state in [State.IDLE, State.PATROL]:
			_enter_stalk()


func _on_detection_zone_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		# si deja de tener objetivo mientras está volando → vuelve a patrulla
		if state in [State.STALK, State.DIVE]:
			_enter_patrol()


# ============================================================
#   REACCIÓN AL DAÑO
# ============================================================
func take_damage(amount: int) -> void:
	# Lógica base de daño (vida, flash, muerte, señales, etc.)
	super.take_damage(amount)

	if is_dead:
		return

	# 🔥 FASE ENRAGED: cuando la vida baja del 40% una sola vez
	if not enraged and health <= int(max_health * 0.4):
		enraged = true
		walk_speed *= 2.0
		fly_speed *= 2.0
		print("[BossKintama] ENRAGED PHASE! walk_speed =", walk_speed, " fly_speed =", fly_speed)

	# Si aún estaba en suelo y ya tiene jugador, lo forzamos a acechar desde el aire
	if state in [State.IDLE, State.PATROL] and is_instance_valid(player):
		_enter_stalk()


# ============================================================
#   RESOLVER REFERENCIA AL PLAYER
# ============================================================
func _refresh_player_ref_from_path() -> void:
	if player_path != NodePath():
		var n := get_node_or_null(player_path)
		if n is CharacterBody2D:
			player = n


func _refresh_player_ref_from_group() -> void:
	var n := get_tree().get_first_node_in_group("player")
	if n and n is CharacterBody2D:
		player = n


# ============================================================
#   ANIMACIÓN (anula la de Enemy)
# ============================================================
func update_animation() -> void:
	# El boss gestiona sus animaciones manualmente (idle/walk/fly),
	# así que no usamos Enemy.update_animation().
	pass
