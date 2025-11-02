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

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var insult_spawn_point: Node2D = $InsultSpawnPoint

func _ready() -> void:
	health = max_health
	add_to_group("enemy")
	
	# Cargar la escena del proyectil de insulto
	insult_scene = preload("res://Assets/Scenes/Enemies Scene/PapaRoberto Scene/Insulto Scene/Insulto.tscn")
	
	# Configurar las áreas de detección y ataque
	setup_detection_area()
	setup_attack_area()
	
	print("👑 Padre RobertoUpdate spawneado con", health, "HP y listos los insultos!")

func _physics_process(delta):
	if health <= 0:
		return
	if not is_on_floor():
		velocity.y += gravity * delta
		
	find_player()
	update_behavior(delta)
	update_animation()
	move_and_slide()

func setup_detection_area():
	detection_area.body_entered.connect(_on_player_detected)
	detection_area.body_exited.connect(_on_player_lost)

func setup_attack_area():
	attack_area.body_entered.connect(_on_attack_range_entered)

func find_player():
	if not player:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

func update_behavior(delta):
	if attack_timer > 0:
		attack_timer -= delta
		
	if not player:
		# Patrulla idle
		idle_behavior()
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player <= attack_range and attack_timer <= 0:
		# Atacar al jugador
		attack_player()
	elif distance_to_player <= detection_range:
		# Perseguir al jugador
		chase_player()
	else:
		# Volver a idle
		idle_behavior()

func idle_behavior():
	velocity.x = 0
	is_attacking = false

func chase_player():
	if not player:
		return
		
	is_attacking = false
	var direction = sign(player.global_position.x - global_position.x)
	
	velocity.x = direction * move_speed
	
	# Voltear sprite según la dirección
	if direction > 0:
		is_facing_right = true
		animated_sprite.flip_h = false
	elif direction < 0:
		is_facing_right = false
		animated_sprite.flip_h = true

func attack_player():
	if is_attacking or attack_timer > 0:
		return
		
	is_attacking = true
	attack_timer = attack_cooldown
	velocity.x = 0
	
	print("👑 Papá Roberto se prepara para gritar!")
	
	# Pequeña pausa dramática antes del grito
	await get_tree().create_timer(0.2).timeout
	
	# Lanzar proyectil de insulto
	launch_insult()
	
	# Esperar a que termine la animación de ataque
	await get_tree().create_timer(0.6).timeout
	is_attacking = false

func launch_insult():
	if not insult_scene or not player:
		return
		
	# Crear el proyectil de insulto
	var insult = insult_scene.instantiate()
	
	# Posicionar el insulto
	insult.global_position = insult_spawn_point.global_position
	
	# Calcular dirección hacia el jugador
	var direction_to_player = (player.global_position - global_position).normalized()
	insult.direction = direction_to_player
	
	# Agregar al nivel
	get_tree().current_scene.add_child(insult)
	
	print("�️ ¡Papá Roberto lanzó un insulto hacia el jugador!")

func update_animation():
	if health <= 0:
		if animated_sprite.animation != "death":
			animated_sprite.play("death")
		return
		
	if is_attacking:
		if animated_sprite.animation != "attack":
			animated_sprite.play("attack")
	elif abs(velocity.x) > 5:  # Solo caminar si se mueve significativamente
		if animated_sprite.animation != "walk":
			animated_sprite.play("walk")
	else:
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")

func take_damage(amount: int):
	health -= amount
	if health < 0:
		health = 0
		
	print("👑 Papá Roberto recibió", amount, "daño! HP:", health)
	
	# Efecto de knockback leve
	var knockback_direction = Vector2.RIGHT if is_facing_right else Vector2.LEFT
	velocity += knockback_direction * -200
	
	if health <= 0:
		die()

func die():
	print("💀 Papá RobertoManfinfla ha muerto!")
	
	# Deshabilitar colisiones
	set_physics_process(false)
	$CollisionShape2D.disabled = true
	
	# Reproducir animación de muerte
	animated_sprite.play("death")
	
	# Remover después de un tiempo
	await animated_sprite.animation_finished
	queue_free()

func _on_player_detected(body):
	if body.is_in_group("player"):
		player = body
		print("👑 Papá Roberto detectó al jugador!")

func _on_player_lost(body):
	if body == player:
		print("👑 Papá Roberto perdió al jugador")
		# No borrar la referencia inmediatamente para persecución

func _on_attack_range_entered(body):
	if body.is_in_group("player") and not is_attacking and attack_timer <= 0:
		attack_player()

# Función para recibir daño de proyectiles
func _on_hitbox_area_entered(area: Area2D):
	if area.is_in_group("projectile"):
		take_damage(10)  # Daño de bala
		area.queue_free()  # Destruir la bala
