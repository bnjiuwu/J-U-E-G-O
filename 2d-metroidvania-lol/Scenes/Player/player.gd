extends CharacterBody2D


#=== dash properties ====
@export var dash_speed: float = 600
@export var dash_time: float = 0.2
@export var dash_cooldown: float = 0.5

var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0


var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var move_speed: float
@export var jump_speed: float
@onready var animated_sprite = $AnimatedSprite2D
var is_facing_right = true
var is_facing_up = false
var facing_direction: Vector2 = Vector2.RIGHT

#============== bullet ===========
@export var bullet_scene: PackedScene
@onready var canon = $muzzle


func _process(delta):
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
	
func update_animation():
	if not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("jump")
			pass
		else:
			animated_sprite.play("fall")
			pass
		return
	
	if velocity.x:
		animated_sprite.play("walk")
	else:
		animated_sprite.play("idle")
		
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

	
