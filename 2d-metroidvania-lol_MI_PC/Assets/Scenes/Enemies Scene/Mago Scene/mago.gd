extends CharacterBody2D

# --- Propiedades ---
@export var speed: float = 30.0
@export var attack_range: float = 200.0
@export var fire_rate: float = 1.5
@export var max_health: int = 5
@export var magic_ball_scene: PackedScene

var health: int
var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

# --- Target & control ---
var player_target: CharacterBody2D = null
var can_fire: bool = true
var direction: int = 1 # 1 derecha, -1 izquierda
var is_attacking: bool = false
var is_dead: bool = false

# --- Nodos ---
@onready var sprite: AnimatedSprite2D = $sprite
@onready var floor_check: RayCast2D = $FloorCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var MagicBallSpawnPoint: Node2D = $MagicBallSpawnPoint
@onready var fire_cooldown: Timer = $FireCooldown
@onready var DetectionZone: Area2D = $DetectionZone

func _ready():
	health = max_health
	add_to_group("enemy")

	fire_cooldown.one_shot = true
	fire_cooldown.timeout.connect(_on_fire_cooldown_timeout)
	
	sprite.frame_changed.connect(_on_frame_changed)

func _physics_process(delta):
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += gravity * delta

	if player_target:
		#print("TARGET PLAYER DETECTED")
		attack_behavior()
	else:
		patrol_movement()

	sprite.flip_h = (direction == -1)
	_update_directional_nodes()
	move_and_slide()
	update_animation()

func _on_frame_changed():
	if not is_attacking:
		return
	if sprite.animation in ["attack1","attack2"] and sprite.frame == 4:
		fire_magic_ball()

# --- Dirección nodos ---
func _update_directional_nodes():
	if floor_check:
		floor_check.position.x = sign(direction) * abs(floor_check.position.x)

	if wall_check:
		wall_check.position.x = sign(direction) * abs(wall_check.position.x)
		wall_check.target_position.x = sign(direction) * abs(wall_check.target_position.x)

	if MagicBallSpawnPoint:
		MagicBallSpawnPoint.position.x = sign(direction) * abs(MagicBallSpawnPoint.position.x)

	if DetectionZone:
		DetectionZone.position.x = sign(direction) * abs(DetectionZone.position.x)

		# 🔧 también invierte la CollisionShape2D interna
		var shape := DetectionZone.get_node_or_null("CollisionShape2D")
		if shape:
			shape.position.x = sign(direction) * abs(shape.position.x)

# --- Patrulla ---
func patrol_movement():
	velocity.x = direction * speed
	if is_on_floor() and not floor_check.is_colliding():
		direction *= -1
	elif is_on_wall() or (wall_check and wall_check.is_colliding()):
		direction *= -1

# --- Ataque ---
func attack_behavior():
	if not player_target:
		return

	direction = 1 if player_target.global_position.x > global_position.x else -1
	var distance := global_position.distance_to(player_target.global_position)

	if distance > attack_range:
		velocity.x = direction * speed
		is_attacking = false
	else:
		velocity.x = 0
		# Solo atacar si puede disparar y no está animando ataque
		if can_fire and not is_attacking:
			is_attacking = true
			can_fire = false
			fire_cooldown.start(fire_rate)
			sprite.play("attack1" if randf() < 0.5 else "attack2")


# --- Disparo ---
func fire_magic_ball():
	if not magic_ball_scene or not player_target or not MagicBallSpawnPoint:
		return

	var bullet = magic_ball_scene.instantiate()
	bullet.global_position = MagicBallSpawnPoint.global_position

	# Calculamos dirección exacta hacia el jugador
	var dir = (player_target.global_position - global_position).normalized()
	bullet.set_direction(dir)

	get_tree().current_scene.add_child(bullet)
	print("[MAGO] Magic ball fired towards:", dir)

# --- Animaciones ---
func update_animation():
	if is_dead:
		sprite.play("death")
	elif is_attacking:
		if not sprite.is_playing() or not sprite.animation.begins_with("attack"):
			sprite.play("attack1" if randf() < 0.5 else "attack2")
	elif abs(velocity.x) > 0:
		sprite.play("run")
	else:
		sprite.play("idle")

# --- Daño ---
func take_damage(amount: int):
	if is_dead:
		return

	health -= amount
	if health <= 0:
		is_dead = true
		sprite.play("death")
		await sprite.animation_finished
		queue_free()

# --- Detección ---
func _on_detection_zone_body_entered(body: Node):
	if body.is_in_group("player"):
		player_target = body
		print("[MAGO] Jugador detectado.")

func _on_detection_zone_body_exited(body: Node):
	if body == player_target:
		player_target = null
		print("[MAGO] Jugador fuera de rango.")

# --- Timer ---
func _on_fire_cooldown_timeout():
	can_fire = true
	
func _on_sprite_animation_finished():
	if sprite.animation.begins_with("attack"):
		is_attacking = false

func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return

	if area.is_in_group("projectile"):
		print("💥 Mago recibió impacto de bala")
		take_damage(1)
		area.queue_free()
