extends CharacterBody2D


#=== dash properties ====
@export var dash_speed: float = 600
@export var dash_time: float = 0.2
@export var dash_cooldown: float = 0.5
  
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0

#===== movement =====
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var move_speed: float
@export var jump_speed: float
@onready var animated_sprite = $AnimatedSprite2D
var is_facing_right = true

var is_facing_up = false
var facing_direction: Vector2 = Vector2.RIGHT

#==== health ======
@export var max_health = 100
var health: int

#============== bullet ===========
@export var bullet_scene: PackedScene
@onready var canon = $muzzle

#==== damage knockback =======
var knockback_force: Vector2 = Vector2(300, -200) # (x: fuerza lateral, y: salto)
var is_knockback: bool = false
var knockback_timer: float = 0.0
var knockback_duration: float = 0.2 # cuánto dura el retroceso



func _ready() -> void:
	health = max_health
	add_to_group("player")
	print("Player HP ready:",health)
	
	pass

func _process(_delta):
	if Input.is_action_just_pressed("attack"):
		fire_bullet()

func _physics_process(delta):
	if not is_dashing:
		jump(delta)
		move_x()
		flip()
		update_animation()
	dash(delta)
	move_and_slide()
		# Check collisions after moving
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if col.get_collider().is_in_group("world damage"):
			print("☠️ Player hit world hazard:", col.get_collider())
			take_damage(100)

	
func update_animation():
	if not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("jump")
			print("jump")
			pass
		else:
			animated_sprite.play("fall")
			print("falling")
			pass
		return
	
	if velocity.x:
		animated_sprite.play("walk")
		print("moving")
	else:
		print("idle")
		animated_sprite.play("idle")

#==== movement ====
func jump(delta):
	# Gravedad siempre
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0  # Reinicia cuando está en suelo
	# Salto
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_speed
func flip():
	if velocity.x > 0:
		is_facing_right = true
		animated_sprite.flip_h = false
	elif velocity.x < 0 :
		is_facing_right = false
		animated_sprite.flip_h = true	
func move_x():
	var input_axis = Input.get_axis("move_left","move_right")
	velocity.x = input_axis * move_speed
#==== fire bullet ===
func fire_bullet():
	var bullet = bullet_scene.instantiate()
	
	#direccion segun input
	var dir = Vector2.ZERO
	if Input.is_action_pressed("look_up"):
		dir = Vector2.UP
		canon.rotation = deg_to_rad(-90)
	elif is_facing_right:
		$muzzle.position.x = abs($muzzle.position.x)

		dir = Vector2.RIGHT
		canon.rotation = 0
	else:
		dir = Vector2.LEFT
		$muzzle.position.x = -abs($muzzle.position.x)
		canon.rotation = deg_to_rad(180)

	bullet.direction = dir
	bullet.global_position = canon.global_position
	bullet.rotation = dir.angle()
	get_tree().current_scene.add_child(bullet)
#=== dash =====
func dash(delta):
	# Si ya está en cooldown, lo contamos
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	# Iniciar dash
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = dash_time
		dash_cooldown_timer = dash_cooldown

	# Mientras dura el dash
	if is_dashing:
		dash_timer -= delta
		var dir = Vector2.RIGHT if is_facing_right else Vector2.LEFT
		velocity = dir * dash_speed

		# terminar dash
		if dash_timer <= 0:
			is_dashing = false

func _on_hitbox_area_entered(area: Area2D) -> void:
	print("⚠️ Player detectó un área:", area.name)
	
	if area.is_in_group("enemy"):
		print("⚡ Player hit by enemy")
		take_damage(20)
	elif area.is_in_group("projectile"):
		print("💥 Daño por proyectil")
		take_damage(10)
		pass
	elif area.is_in_group("world damage"):
		print("daño por pincho")
		take_damage(100)
		
func take_damage(amount) -> void:
	health -= amount
	if health < 0:
		health = 0
	print("⚠️ Player recibió", amount, "daño | HP:", health)

	if health <= 0:
		die()

func die() -> void:
	print("💀 Player ha muerto")
	queue_free() # aquí puedes cambiarlo por animación/game over
