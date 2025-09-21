extends CharacterBody2D

@export var speed: float = 60
@export var raycast_ahead: float = 10.0
@export var raycast_down: float = 20.0
@export var gravity: float = 900.0
@export var flip_debounce: float = 0.12

# --- Vida del enemigo ---
@export var max_health: int = 3
var health: int
var start_pos: Vector2

var direction: int = -1
var flip_timer: float = 0.0

@onready var floor_check: RayCast2D = $floor_check
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Area2D  # asegúrate que tu enemigo tenga un Area2D con CollisionShape2D

func _ready():
	# Vida inicial
	health = max_health
	start_pos = global_position
	
	# Agrupar al enemigo
	add_to_group("enemies")
	
	# Conectar señal del Area2D
	hitbox.area_entered.connect(_on_area_2d_area_entered)
	
	# Inicializar animación
	sprite.flip_h = direction == 1

func _physics_process(delta):
	sprite.play("slime_idle")
	if flip_timer > 0.0:
		flip_timer -= delta

	# Actualizar raycast
	var tp = floor_check.target_position
	tp.x = raycast_ahead * direction
	tp.y = raycast_down
	floor_check.target_position = tp

	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Movimiento
	if is_on_floor():
		velocity.x = speed * direction
	else:
		velocity.x = 0

	move_and_slide()

	# Detectar borde
	if is_on_floor() and not floor_check.is_colliding() and flip_timer <= 0.0:
		direction *= -1
		sprite.flip_h = direction == 1
		flip_timer = flip_debounce

# --- Sistema de daño ---
func take_damage(amount: int):
	health -= amount
	print("Enemy HP:", health)
	if health <= 0:
		queue_free()

func _on_area_2d_area_entered(area: Area2D):
	if area.is_in_group("bullet"): # si entra una bala
		take_damage(1)              # hacer daño al enemigo
		area.queue_free()           # destruir la bala
