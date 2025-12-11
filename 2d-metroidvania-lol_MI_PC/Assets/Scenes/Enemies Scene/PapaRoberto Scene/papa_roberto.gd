extends CharacterBody2D

@export var move_speed: float = 50.0
@export var max_health: int = 150
@export var damage: int = 30
@export var detection_range: float = 140.0
@export var attack_range: float = 150.0
@export var attack_cooldown: float = 2.0
@export var insult_scene: PackedScene
@export var wall_flip_cooldown: float = 0.35
@export var wall_push_distance: float = 8.0

var health: int
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var player: CharacterBody2D
var is_attacking: bool = false
var attack_timer: float = 0.0
var is_facing_right: bool = true
var is_dead: bool = false
var direction: int = 0
var _wall_flip_timer: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var insult_spawn_point: Node2D = $InsultSpawnPoint
@onready var floor_check : RayCast2D = $RayCast2D
@onready var detection_shape: CollisionShape2D = detection_area.get_node_or_null("CollisionShape2D") if detection_area else null
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")
@onready var health_label: Label = get_node_or_null("HealthBarNumber")

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	insult_scene = preload("res://Assets/Scenes/Enemies Scene/PapaRoberto Scene/Insulto Scene/Insulto.tscn")
	setup_detection_area()
	setup_attack_area()
	_update_health_ui()

func _physics_process(delta):
	_wall_flip_timer = max(_wall_flip_timer - delta, 0.0)

	# Actualizar raycast
	var tp = floor_check.target_position
	tp.x = 10 * direction
	tp.y = 30
	floor_check.target_position = tp
	if is_dead:
		return
	
	if not is_on_floor():
		velocity.y += gravity * delta

	find_player()
	update_behavior(delta)
	update_animation()
	move_and_slide()
	_resolve_wall_stick()
	_handle_platform_boundaries()
		


# --- Áreas de detección ---
func setup_detection_area():
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost)
	_update_detection_shape()

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

		else:
			velocity.x = direction * move_speed
			is_facing_right = direction > 0
			animated_sprite.flip_h = not is_facing_right


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
	direction = dir if dir != 0 else direction
	is_facing_right = dir > 0
	animated_sprite.flip_h = not is_facing_right

# --- Ataque ---
func attack_player():
	if is_attacking or attack_timer > 0:
		return
	
	is_attacking = true
	attack_timer = attack_cooldown
	velocity.x = 0


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


# --- Animaciones ---
func update_animation():
	if is_dead:
		
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
	health = clamp(health, 0, max_health)
	print("💥 Papa Roberto recibió", amount, "daño | HP:", health)
	_update_health_ui()

	if health <= 0:
		die()

# --- Muerte ---
func die():
	if is_dead:
		return

	is_dead = true

	
	# Desactivamos colisiones para que no siga molestando
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Detenemos la lógica física
	set_physics_process(false)

	# --- ¡AQUÍ ESTÁ LA SEÑAL PARA FLAMBO! ---
	GlobalsSignals.enemy_defeated.emit()
	# ----------------------------------------

	if health_bar:
		health_bar.visible = false
	if health_label:
		health_label.visible = false

	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
		animated_sprite.play("death")
		await animated_sprite.animation_finished

	queue_free()

# --- Señales ---
func _on_player_detected(body):
	if body.is_in_group("player"):
		player = body


func _on_player_lost(body):
	if body == player:

		player = null

func _on_attack_range_entered(body):
	if body.is_in_group("player") and not is_attacking and attack_timer <= 0:
		attack_player()

func _on_hitbox_area_entered(area: Area2D):
	if area.is_in_group("projectile"):
		if area is PlayerProjectile:
			return
		if "damage" in area:
			take_damage(area.damage)
		area.queue_free()
	if area.is_in_group("Skills"):
		if area is PlayerProjectile:
			return

		take_damage(area.damage)
		area.queue_free()

func _resolve_wall_stick() -> void:
	if not is_on_wall():
		return
	if _wall_flip_timer > 0.0:
		return

	_wall_flip_timer = wall_flip_cooldown
	var new_dir = direction
	if new_dir == 0:
		new_dir = -1 if is_facing_right else 1
	new_dir *= -1
	direction = new_dir
	is_facing_right = direction > 0
	animated_sprite.flip_h = not is_facing_right
	velocity.x = direction * move_speed
	global_position.x += direction * wall_push_distance

func _handle_platform_boundaries() -> void:
	var should_flip := false
	if floor_check and is_on_floor() and not floor_check.is_colliding():
		should_flip = true
	if is_on_wall():
		should_flip = true
	if not should_flip:
		return

	if direction == 0:
		direction = -1 if is_facing_right else 1

	direction *= -1
	is_facing_right = direction > 0
	animated_sprite.flip_h = not is_facing_right
	velocity.x = direction * move_speed
	if detection_shape:
		detection_shape.position.x = abs(detection_shape.position.x) * (1 if is_facing_right else -1)
func _update_detection_shape() -> void:
	if detection_shape == null or detection_shape.shape == null:
		return

	var range: float = max(detection_range, 10.0)
	var total_length: float = range * 2.0
	var shape_res := detection_shape.shape

	if shape_res is CapsuleShape2D:
		var capsule := shape_res as CapsuleShape2D
		capsule.radius = min(capsule.radius, range)
		capsule.height = max(total_length - capsule.radius * 2.0, 0.0)
	elif shape_res is RectangleShape2D:
		shape_res.size.x = total_length
	elif shape_res is CircleShape2D:
		shape_res.radius = range

func _update_health_ui() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = clamp(health, 0, max_health)
		health_bar.visible = true
	if health_label:
		health_label.text = str(clamp(health, 0, max_health))
		health_label.visible = true
