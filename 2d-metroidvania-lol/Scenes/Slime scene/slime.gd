extends CharacterBody2D

@export var speed: float = 50
@export var patrol_distance: float = 100
@export var max_health: int = 3

var direction := -1 # -1 = izquierda, 1 = derecha
@onready var floor_check: RayCast2D = $floor_check
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

#==== health system ====
var health: int
var start_pos: Vector2
func _ready():
	health = max_health
	start_pos = global_position
	add_to_group("enemies")

func _physics_process(delta):
	# movimiento
	velocity.x = speed * direction
	move_and_slide()

	# el raycast siempre apunta adelante según la dirección actual
	floor_check.cast_to.x = 10 * direction

	# si está en el suelo y no hay suelo adelante → cambiar dirección
	if is_on_floor() and not floor_check.is_colliding():
		direction *= -1
		sprite.flip_h = direction == 1
		
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
