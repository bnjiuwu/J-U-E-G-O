extends CharacterBody2D

@export var move_speed: float
@export var jump_speed: float
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var animated_sprite = $AnimatedSprite2D
var is_facing_right = true

#============== bullet ===========
@export var bullet_scene: PackedScene
@onready var muzzle: Marker2D = $cañon


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
	var dir = Vector2.RIGHT if is_facing_right else Vector2.LEFT
	bullet.direction = dir
	bullet.global_position = $cañon.global_position
	get_parent().add_child(bullet)
