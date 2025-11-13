extends CharacterBody2D

# --- Estados de Movimiento ---
enum State { IDLE, PATROL, ATTACK }

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
@export var walk_speed: float = 55.0
@export var fly_speed: float = 90.0
@export var attack_duration: float = 1.6
@export var attack_cooldown: float = 1.2
@export var contact_damage: int = 20
@export var max_health: int = 200

# --- Detección del Jugador ---
@export var player_path: NodePath
@export var detection_radius: float = 100.0 # Fallback por distancia

# --- Variables Internas ---
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
var state: State = State.IDLE
var idle_timer: float = 0.0
var attack_timer: float = 0.0
var cooldown_timer: float = 0.0
var direction: int = -1
var player: CharacterBody2D = null
var _health: int = 0

# --- Referencias de Nodos ---
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var floor_check: RayCast2D = $FloorCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var detection_area: Area2D = $DetectionZone
@onready var hitbox: Area2D = $Hitbox if has_node("Hitbox") else null


func _ready() -> void:
	idle_timer = randf_range(idle_wait_range.x, idle_wait_range.y)
	_refresh_player_ref_from_path()
	_health = max_health

	# Configurar Raycasts (solo colisionan con el mundo)
	for ray in [floor_check, wall_check]:
		if ray == null: continue
		ray.enabled = true
		ray.exclude_parent = true
		ray.collide_with_areas = false
		ray.collide_with_bodies = true
		ray.set_collision_mask_value(LAYER_WORLD, true)

	# Configurar Zona de Detección (solo detecta al jugador)
	if detection_area:
		detection_area.set_collision_mask_value(LAYER_PLAYER, true)
		# Las señales (body_entered/exited) deben estar conectadas en el editor

	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.area_entered.connect(_on_hitbox_area_entered)

	sprite.play("idle")
	_update_directional_nodes()


func _physics_process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

	# 1. Asegurar que la referencia al jugador sea válida
	if not is_instance_valid(player):
		_refresh_player_ref_from_path() # Intentar por NodePath
		if not is_instance_valid(player):
			_refresh_player_ref_from_group() # Intentar por grupo

	# 2. Lógica de Detección (si el jugador existe)
	if is_instance_valid(player) and state != State.ATTACK and cooldown_timer <= 0.0:
		# Fallback por distancia (si el Area2D falla)
		var dist := global_position.distance_to(player.global_position)
		if dist <= detection_radius:
			_enter_attack()

	# 3. Máquina de Estados (FSM)
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
			# Girar si no hay suelo o hay pared
			if (floor_check and not floor_check.is_colliding()) or \
			   (wall_check and wall_check.is_colliding()) or \
			   is_on_wall():
				_flip_direction()

		State.ATTACK:
			attack_timer -= delta
			if not is_instance_valid(player) or attack_timer <= 0.0:
				_enter_idle() # Volver a idle si el jugador desaparece o se acaba el tiempo
			else:
				# Perseguir al jugador (volar)
				var dir_vec := (player.global_position - global_position).normalized()
				velocity = dir_vec * fly_speed
				sprite.flip_h = dir_vec.x < 0

	# 4. Actualizar nodos y mover
	_update_directional_nodes()
	move_and_slide()


func _apply_ground_physics(delta: float) -> void:
	if is_on_floor():
		velocity.y = min(velocity.y, 0.0)
	else:
		velocity.y += gravity * delta

func _update_directional_nodes() -> void:
	# El sprite solo se flipea si no está atacando
	if state != State.ATTACK:
		sprite.flip_h = direction < 0
	
	# Mover los raycasts según la dirección
	if floor_check:
		floor_check.position = Vector2(direction * FLOOR_AHEAD_X, FLOOR_CHECK_Y)
		floor_check.target_position = Vector2(0.0, FLOOR_DOWN_Y)
		floor_check.force_raycast_update()
	if wall_check:
		wall_check.position = Vector2(direction * WALL_CHECK_OFFSET_X, WALL_CHECK_OFFSET_Y)
		wall_check.target_position = Vector2(direction * WALL_LEN, WALL_CHECK_OFFSET_Y)
		wall_check.force_raycast_update()

func _flip_direction() -> void:
	direction *= -1
	# Reiniciar timer de idle para evitar giros infinitos si se atasca
	if state == State.PATROL:
		_enter_idle()

# --- Máquina de Estados ---

func _enter_idle() -> void:
	state = State.IDLE
	idle_timer = randf_range(idle_wait_range.x, idle_wait_range.y)
	sprite.play("idle")
	attack_timer = 0.0
	velocity.x = 0

func _enter_patrol() -> void:
	state = State.PATROL
	sprite.play("walk")

func _enter_attack() -> void:
	if not is_instance_valid(player):
		return
	state = State.ATTACK
	attack_timer = attack_duration
	cooldown_timer = attack_cooldown
	sprite.play("fly")

# --- Detección del Jugador (Señales del Editor) ---

func _on_detection_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as CharacterBody2D
		if state != State.ATTACK and cooldown_timer <= 0.0:
			_enter_attack()

func _on_detection_zone_body_exited(body: Node2D) -> void:
	if body == player:
		player = null # Pierde el objetivo, pero seguirá atacando hasta que termine el timer

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(contact_damage, global_position)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		var player_body := area.get_parent()
		if player_body and player_body.has_method("take_damage"):
			player_body.take_damage(contact_damage, global_position)
	elif area.has_method("take_damage"):
		area.take_damage(contact_damage)

func take_damage(amount: int) -> void:
	_health -= amount
	if _health <= 0:
		_die()
		return
	if state != State.ATTACK:
		_enter_attack()

func _die() -> void:
	queue_free()

# --- Helpers para Referencia del Jugador ---

func _refresh_player_ref_from_path() -> void:
	if player_path != NodePath():
		var n := get_node_or_null(player_path)
		if n is CharacterBody2D:
			player = n

func _refresh_player_ref_from_group() -> void:
	var n := get_tree().get_first_node_in_group("player")
	if n and n is CharacterBody2D:
		player = n
