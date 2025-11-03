extends CharacterBody2D

# --- Propiedades ---
@export var patrol_speed: float = 40.0
@export var dive_speed: float = 260.0
@export var retreat_speed: float = 180.0
@export var attack_cooldown: float = 1.5
@export var charge_time: float = 0.5
@export var max_health: int = 3
@export var damage_amount: int = 20
@export var flip_cooldown: float = 0.4
@export var dive_duration: float = 1.5
@export var wave_amp: float = 40.0          # amplitud de la onda
@export var wave_freq_ms: float = 300.0     # periodo de la onda (ms)
@export var kick_strength: float = 180.0    # fuerza del impulso vertical
@export var kick_duration: float = 0.15     # duración del impulso (s)

var _kick_timer: float = 0.0
var _kick_dir: int = 0   # -1 = hacia arriba (suelo), +1 = hacia abajo (techo)


var health: int
var is_dead: bool = false

var _flip_lock := 0.0
var _attack_cooldown_timer := 0.0
var _charge_timer := 0.0
var _retreat_timer := 0.0
var _detect_lock_timer := 0.0
var _dive_timer := 0.0
var _lift_cooldown := 0.0  # 🕒 evita impulsos seguidos al suelo/techo

# --- Estados ---
enum State { PATROL, CHARGING, DIVE, RETREAT }
var current_state = State.PATROL
var player_target: CharacterBody2D = null
var direction: int = -1
var dive_direction: Vector2 = Vector2.ZERO

# --- Nodos ---
@onready var sprite: AnimatedSprite2D = $animated
@onready var wall_check: RayCast2D = $WallCheck
@onready var floor_check: RayCast2D = $FloorCheck
@onready var ceiling_check: RayCast2D = $CeilingCheck
@onready var detection_zone: Area2D = $DetectionZone
@onready var hitbox: Area2D = $Hitbox

# --- Ready ---
func _ready():
	health = max_health
	if sprite:
		sprite.play("fly2")
	setup_sensors()

# --- Física ---
func _physics_process(delta):
	if is_dead:
		return

	_flip_lock = max(_flip_lock - delta, 0)
	_lift_cooldown = max(_lift_cooldown - delta, 0)
	if _attack_cooldown_timer > 0:
		_attack_cooldown_timer -= delta
	if _detect_lock_timer > 0:
		_detect_lock_timer -= delta

	match current_state:
		State.PATROL:
			patrol_behavior(delta)
		State.CHARGING:
			charge_behavior(delta)
		State.DIVE:
			dive_behavior(delta)
		State.RETREAT:
			retreat_behavior(delta)

	if current_state in [State.PATROL, State.RETREAT]:
		_check_floor_and_lift(delta)
		_check_ceiling_and_lower(delta)
		
	if sprite:
		sprite.flip_h = (direction == 1)

	_update_directional_nodes()
	# --- Ajuste de altura automática ---
		
	move_and_slide()


# --- Setup ---
func setup_sensors():
	if wall_check: wall_check.enabled = true
	if floor_check: floor_check.enabled = true
	if ceiling_check: ceiling_check.enabled = true
	if detection_zone:
		detection_zone.monitoring = true
		detection_zone.monitorable = true

func _update_directional_nodes():
	if wall_check:
		wall_check.position.x = sign(direction) * abs(wall_check.position.x)
		wall_check.target_position.x = sign(direction) * abs(wall_check.target_position.x)
	if detection_zone:
		detection_zone.position.x = sign(direction) * abs(detection_zone.position.x)

# --- Patrulla ---
func patrol_behavior(delta):
	# Movimiento horizontal
	velocity.x = direction * patrol_speed

	# --- ONDA BASE SIEMPRE ACTIVA ---
	var base_vy = sin(Time.get_ticks_msec() / wave_freq_ms) * wave_amp

	# --- DETECCIÓN Y DISPARO DEL KICK SOLO UNA VEZ ---
	var hit_floor := floor_check and floor_check.is_colliding()
	var hit_ceiling := ceiling_check and ceiling_check.is_colliding()

	# dispara el kick solo si no hay uno activo
	if _kick_timer <= 0.0:
		if hit_floor:
			# distancia al suelo para no disparar de más lejos
			var dist_ok := true
			if floor_check:
				var d = floor_check.get_collision_point().y - global_position.y
				dist_ok = d < 25.0
			if dist_ok:
				_kick_dir = -1
				_kick_timer = kick_duration
		elif hit_ceiling:
			var dist_ok2 := true
			if ceiling_check:
				var d2 = global_position.y - ceiling_check.get_collision_point().y
				dist_ok2 = d2 < 25.0
			if dist_ok2:
				_kick_dir = +1
				_kick_timer = kick_duration

	# --- APLICA EL KICK CON DECAIMIENTO ---
	var kick_vy := 0.0
	if _kick_timer > 0.0:
		_kick_timer -= delta
		var t: float = clamp(_kick_timer / kick_duration, 0.0, 1.0)
		# decaimiento lineal (puedes cambiar a t*t para curva)
		kick_vy = _kick_dir * kick_strength * t
	else:
		_kick_dir = 0

	# Combinación: onda + impulso (sin eliminar la onda)
	velocity.y = base_vy + kick_vy

	# Flip por pared con debounce
	if wall_check and wall_check.is_colliding() and _flip_lock <= 0.0:
		_flip()


# --- Carga ---
func charge_behavior(delta):
	_charge_timer -= delta
	velocity = Vector2.ZERO
	if sprite:
		sprite.play("charge")

	# ⚠️ Desactivar detección mientras carga
	if detection_zone:
		detection_zone.monitoring = false
		detection_zone.monitorable = false

	if _charge_timer <= 0:
		if player_target:
			direction = 1 if player_target.global_position.x > global_position.x else -1
			_update_directional_nodes()
			dive_direction = (player_target.global_position - global_position).normalized()
		else:
			dive_direction = Vector2(direction, 0)

		current_state = State.DIVE
		_dive_timer = dive_duration
		_detect_lock_timer = 1.8

# --- Dive ---
func dive_behavior(delta):
	_dive_timer -= delta
	velocity = dive_direction * dive_speed

	if detection_zone:
		detection_zone.monitoring = false
		detection_zone.monitorable = false

	# Fin del dive por pared o tiempo
	if wall_check and wall_check.is_colliding():
		var normal = wall_check.get_collision_normal()
		if abs(normal.x) > 0.5:
			on_attack_hit_player()
	elif _dive_timer <= 0.0:
		print("[🦇] Dive finalizado (tiempo límite)")
		current_state = State.PATROL
		player_target = null
		_detect_lock_timer = 0.8
		if detection_zone:
			detection_zone.monitoring = true
			detection_zone.monitorable = true

# --- Retroceso ---
func retreat_behavior(delta):
	_retreat_timer -= delta
	velocity = Vector2(-direction, 0).normalized() * retreat_speed
	if _retreat_timer <= 0:
		current_state = State.PATROL
		player_target = null
		_detect_lock_timer = 0.5
		if detection_zone:
			detection_zone.monitoring = true
			detection_zone.monitorable = true

# --- Transición tras ataque ---
func on_attack_hit_player():
	_retreat_timer = 0.6
	current_state = State.RETREAT
	_attack_cooldown_timer = attack_cooldown
	_detect_lock_timer = 1.5

# --- Comprobación de suelo y techo ---
func _check_floor_and_lift(delta: float):
	if not floor_check:
		return

	if floor_check.is_colliding():
		var dist_to_floor = floor_check.get_collision_point().y - global_position.y
		if dist_to_floor < 25:
			# 💨 impulso más suave hacia arriba (lerp para transición fluida)
			var target_y = -120.0  # fuerza vertical deseada
			velocity.y = lerp(velocity.y, target_y, 8.0 * delta)

			print("[🦇] Impulso hacia arriba (suelo detectado)")
			velocity.y = -180.0
			_lift_cooldown = 0.3

func _check_ceiling_and_lower(delta: float):
	if not ceiling_check:
		return

	if ceiling_check.is_colliding():
		var dist_to_ceiling = global_position.y - ceiling_check.get_collision_point().y
		if dist_to_ceiling < 25:
			# 💨 impulso más suave hacia abajo
			var target_y = 120.0
			velocity.y = lerp(velocity.y, target_y, 8.0 * delta)

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

# --- Daño ---
func take_damage(amount: int):
	if is_dead:
		return
	health -= amount
	if health <= 0:
		die()

# --- Detección ---
func _on_detection_zone_body_entered(body: Node):
	if _detect_lock_timer > 0 or current_state in [State.CHARGING, State.DIVE, State.RETREAT]:
		return
	if body.is_in_group("player"):
		player_target = body
		_charge_timer = charge_time
		current_state = State.CHARGING
		print("[🦇] Jugador detectado → inicia carga")

func _on_detection_zone_body_exited(body: Node):
	if body == player_target and current_state == State.PATROL:
		player_target = null
		print("[🦇] Jugador fuera de rango")

# --- Hitbox ---
func _on_hitbox_area_entered(area: Area2D):
	if is_dead: return
	if area.is_in_group("projectile"):
		print("💥 Murciélago recibió bala")
		take_damage(area.damage)
		area.queue_free()
	if area.is_in_group("Skills"):
		print("💥 Mago recibió impacto de bala")
		take_damage(area.damage)
		area.queue_free()

# --- Muerte ---
func die():
	if is_dead: return
	is_dead = true
	print("💀 Murciélago ha muerto")

	velocity = Vector2.ZERO
	set_physics_process(false)
	if detection_zone:
		detection_zone.monitoring = false
		detection_zone.monitorable = false
	if wall_check:
		wall_check.enabled = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true

	if sprite and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	else:
		var tween := get_tree().create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
	queue_free()
