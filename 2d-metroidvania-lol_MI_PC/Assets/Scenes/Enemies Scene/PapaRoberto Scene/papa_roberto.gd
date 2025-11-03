extends CharacterBody2D

@export var move_speed: float = 50.0
@export var max_health: int = 150
@export var damage: int = 30
@export var detection_range: float = 140.0
@export var attack_range: float = 150.0
@export var attack_cooldown: float = 2.0
@export var insult_scene: PackedScene

var health: int
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var player: CharacterBody2D
var is_attacking: bool = false
var attack_timer: float = 0.0
var is_facing_right: bool = true
var is_dead: bool = false
var direction: int = 0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var insult_spawn_point: Node2D = $InsultSpawnPoint

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	insult_scene = preload("res://Assets/Scenes/Enemies Scene/PapaRoberto Scene/Insulto Scene/Insulto.tscn")
	setup_detection_area()
	setup_attack_area()
	print("👑 Padre Roberto listo con", health, "HP")

func _physics_process(delta):
	if is_dead:
		return
	
	if not is_on_floor():
		velocity.y += gravity * delta

	find_player()
	update_behavior(delta)
	update_animation()
	move_and_slide()

# --- Áreas de detección ---
func setup_detection_area():
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost)

func setup_attack_area():
	attack_area.body_entered.connect(_on_attack_range_entered)

# --- Buscar jugador ---
func find_player():
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

# --- Lógica principal ---
func update_behavior(delta):
	if attack_timer > 0:
		attack_timer -= delta
	
	if not player:
		idle_behavior()
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range and attack_timer <= 0:
		attack_player()
	elif distance_to_player <= detection_range:
		chase_player()
	else:
		idle_behavior()

# --- Patrulla aleatoria ---
func idle_behavior():
	if is_dead:
		return

	if not has_node("IdleTimer"):
		var timer := Timer.new()
		timer.name = "IdleTimer"
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(_on_idle_timeout)
		
		var choices = [-1, 0, 1]
		direction = choices[randi() % choices.size()]
		is_attacking = false

		if direction == 0:
			velocity.x = 0
			print("🧘 Papa Roberto se queda quieto")
		else:
			velocity.x = direction * move_speed
			is_facing_right = direction > 0
			animated_sprite.flip_h = not is_facing_right
			print("🚶 Papa Roberto camina en dirección:", direction)

		timer.start(randf_range(1.5, 3.0))

func _on_idle_timeout():
	if has_node("IdleTimer"):
		get_node("IdleTimer").queue_free()
	idle_behavior()

# --- Persecución ---
func chase_player():
	if not player:
		return

	is_attacking = false
	var dir = sign(player.global_position.x - global_position.x)
	velocity.x = dir * move_speed
	is_facing_right = dir > 0
	animated_sprite.flip_h = not is_facing_right

# --- Ataque ---
func attack_player():
	if is_attacking or attack_timer > 0:
		return
	
	is_attacking = true
	attack_timer = attack_cooldown
	velocity.x = 0

	print("👑 Papa Roberto se prepara para insultar...")
	await get_tree().create_timer(0.3).timeout

	launch_insult()
	await get_tree().create_timer(0.6).timeout
	is_attacking = false

# --- Disparo ---
func launch_insult():
	if not insult_scene or not player:
		return
	
	var insult = insult_scene.instantiate()
	insult.global_position = insult_spawn_point.global_position
	var direction_to_player = (player.global_position - global_position).normalized()
	insult.direction = direction_to_player
	get_tree().current_scene.add_child(insult)
	print("📢 ¡Papa Roberto lanzó un insulto!")

# --- Animaciones ---
func update_animation():
	if is_dead:
		if animated_sprite.animation != "death":
			animated_sprite.play("death")
		return

	if is_attacking:
		if animated_sprite.animation != "attack":
			animated_sprite.play("attack")
	elif abs(velocity.x) > 5:
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

# --- Daño ---
func take_damage(amount: int):
	if is_dead:
		return
	
	health -= amount
	print("💥 Papa Roberto recibió", amount, "daño | HP:", health)

	var knockback_dir = Vector2.RIGHT if is_facing_right else Vector2.LEFT
	velocity += knockback_dir * -150
	
	if health <= 0:
		die()

# --- Muerte ---
func die():
	if is_dead:
		return

	is_dead = true
	print("💀 Papa Roberto ha muerto")
	
	$CollisionShape2D.disabled = true
	animated_sprite.play("death")
	set_physics_process(false)
	await animated_sprite.animation_finished
	queue_free()

# --- Señales ---
func _on_player_detected(body):
	if body.is_in_group("player"):
		player = body
		print("🎯 Jugador detectado")

func _on_player_lost(body):
	if body == player:
		print("❌ Jugador perdido")
		player = null

func _on_attack_range_entered(body):
	if body.is_in_group("player") and not is_attacking and attack_timer <= 0:
		attack_player()

func _on_hitbox_area_entered(area: Area2D):
	if area.is_in_group("projectile"):
		take_damage(area.damage)
		area.queue_free()
	if area.is_in_group("Skills"):
		print("💥 Mago recibió impacto de bala")
		take_damage(area.damage)
		area.queue_free()
