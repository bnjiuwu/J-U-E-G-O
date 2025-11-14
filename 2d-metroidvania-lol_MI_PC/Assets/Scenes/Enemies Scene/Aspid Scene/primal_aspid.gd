extends CharacterBody2D

# --- CONFIGURABLES ---
@export var patrol_range: float = 150.0
@export var move_speed: float = 60.0
@export var hover_amplitude: float = 25.0
@export var hover_frequency: float = 3.0
@export var attack_cooldown: float = 2.0
@export var attack_spread_deg: float = 25.0
@export var projectile_scene: PackedScene
@export var max_health: int = 80
@export var damage: int = 10

# --- COMPORTAMIENTO DE COMBATE ---
@export var detect_distance: float = 300.0
@export var ideal_distance: float = 150.0
@export var retreat_speed: float = 100.0

# --- INTERNAS ---
var start_position: Vector2
var direction: int = 1
var hover_time: float = 0.0
var player: Node2D = null
var health: int
var in_combat: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var spawn_point: Node2D = $ShootSpawnPoint
@onready var attack_timer: Timer = $AttackTimer
@onready var detection_area: Area2D = $DetectionArea

# --- INICIO ---
func _ready():
	start_position = global_position
	health = max_health
	attack_timer.wait_time = attack_cooldown
	attack_timer.start()
	detection_area.connect("body_entered", Callable(self, "_on_DetectionArea_body_entered"))
	detection_area.connect("body_exited", Callable(self, "_on_DetectionArea_body_exited"))

# --- LOOP ---
func _physics_process(delta):
	sprite.play("idle")
	_hover_movement(delta)
	
	if in_combat and player:
		_combat_movement(delta)
	else:
		_patrol_logic()

# --- MOVIMIENTO HOVER ---
func _hover_movement(delta):
	hover_time += delta * hover_frequency
	var vertical = sin(hover_time) * hover_amplitude
	velocity.y = vertical

# --- MOVIMIENTO PATRULLA ---
func _patrol_logic():
	velocity.x = direction * move_speed
	move_and_slide()
	if abs(global_position.x - start_position.x) > patrol_range:
		direction *= -1
		sprite.flip_h = direction < 0

# --- MOVIMIENTO EN COMBATE ---
func _combat_movement(delta):
	if not player:
		return

	var to_player = player.global_position - global_position
	var distance = to_player.length()

	# Girar hacia jugador
	sprite.flip_h = (player.global_position.x < global_position.x)

	# Mantener distancia óptima
	if distance > ideal_distance + 50:
		velocity.x = move_speed * sign(to_player.x)  # acercarse
	elif distance < ideal_distance - 50:
		velocity.x = -retreat_speed * sign(to_player.x)  # alejarse
	else:
		velocity.x = 0  # quedarse quieto horizontalmente
	
	move_and_slide()

# --- DETECCIÓN ---
func _on_DetectionArea_body_entered(body):
	if body.is_in_group("player"):
		player = body
		in_combat = true
		print("👁️ Aspid detectó al jugador")

func _on_DetectionArea_body_exited(body):
	if body == player:
		player = null
		in_combat = false
		rotation_degrees = 0  # ← devuelve el Aspid a posición recta
		print("👁️ Aspid perdió de vista al jugador")

# --- ATAQUE ---
func _on_AttackTimer_timeout():
	if in_combat and player and not is_queued_for_deletion():
		attack()

func attack():
	if not is_instance_valid(player):
		return

	sprite.play("idle") # o "shoot" si tienes animación

	# Calcular dirección base sin rotar al enemigo
	var base_dir = (player.global_position - spawn_point.global_position).normalized()

	for angle in [-attack_spread_deg, 0, attack_spread_deg]:
		var proj = projectile_scene.instantiate()
		get_tree().current_scene.add_child(proj)
		proj.global_position = spawn_point.global_position
		# Rotamos solo el vector de dirección, no el nodo
		var dir = base_dir.rotated(deg_to_rad(angle))
		proj.set_direction(dir)

	print("⚔️ Aspid dispara!")


# --- RECIBIR DAÑO ---
func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		print("💥 Aspid recibió proyectil")
		take_damage(area.damage)
		area.queue_free()
	elif area.is_in_group("Skills"):
		print("💥 Aspid recibió habilidad fuerte")
		take_damage(area.damage)
		area.queue_free()
	
# --- DAÑO Y MUERTE ---
func take_damage(amount: int):
	health -= amount
	print("Aspid herido: ", health, " HP restantes")
	if health <= 0:
		die()

func die():
	print("💀 Aspid destruido")
	queue_free()
