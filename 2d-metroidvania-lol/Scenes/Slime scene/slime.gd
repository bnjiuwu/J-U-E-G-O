extends CharacterBody2D

@export var speed: float = 50
@export var patrol_distance: float = 100
@export var max_health: int = 3
@onready var animated_sprite = $AnimatedSprite2D


var direction = -1

@onready var ray = $RayCast2D

var health: int
var start_pos: Vector2


func _ready():
	health = max_health
	start_pos = global_position
	add_to_group("enemies")

func _physics_process(delta):
	velocity.x = direction * speed
	if not is_on_floor():
		velocity.y += 900 * delta

	# Detectar borde
	if not ray.is_colliding():
		direction *= -1
		scale.x = -scale.x
		ray.position.x *= -1

	move_and_slide()

# 🩸 Recibir daño (llamar cuando una bala colisione)
func take_damage(amount: int):
	health -= amount
	print("Enemy HP:", health)
	if health <= 0:
		queue_free()

func _on_area_2d_area_entered(area: Area2D):
	if area.is_in_group("bullet"):
		take_damage(1)
		area.queue_free() # destruir la bala
	pass # Replace with function body.
