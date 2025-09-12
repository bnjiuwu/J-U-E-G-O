extends CharacterBody2D

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var move_speed: float
@export var jump_speed: float
@onready var animated_sprite = $AnimatedSprite2D
var is_facing_right = true
var facing_direction: Vector2 = Vector2.RIGHT

#============== bullet ===========
@export var bullet_scene: PackedScene
@onready var canon = $muzzle


func _process(delta):
	if Input.is_action_just_pressed("attack"):
		fire_bullet()

func _physics_process(delta):
	jump(delta)
	move_x()
	flip()
	update_animation()
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
