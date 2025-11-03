extends CharacterBody2D

@export var speed: float = 60
@export var raycast_ahead: float = 10.0
@export var raycast_ahead_wall: float = 22.0
@export var raycast_down: float = 20.0
@export var gravity: float = 900.0
@export var flip_debounce: float = 0.12

# --- Vida del enemigo ---
@export var max_health: int = 3
var health: int
var start_pos: Vector2

var is_dead: bool = false

var direction: int = -1
var flip_timer: float = 0.0

@onready var floor_check: RayCast2D = $floor_check
@onready var wall_check: RayCast2D = $wall_check
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var fisic_hb: CollisionShape2D = $fisic_hitbox
@onready var hitbox: Area2D = $Area2D  # asegúrate que tu enemigo tenga un Area2D con CollisionShape2D

func _ready():
	# Vida inicial
	health = max_health
	start_pos = global_position
	
	# Agrupar al enemigo
	add_to_group("enemy")
	
	# Conectar señal del Area2D
	hitbox.area_entered.connect(_on_area_2d_area_entered)
	
	sprite.animation_finished.connect(_on_animated_sprite_2d_animation_finished)  
	
	# Inicializar animación
	sprite.flip_h = direction == 1
	
func _process(delta):
	# Revisión manual por si la señal no se activa
	if is_dead and not sprite.is_playing():
		print("💀 Slime eliminado (por fin!)")
		queue_free()

func _physics_process(delta):

	if flip_timer > 0.0:
		flip_timer -= delta

	# Actualizar raycast
	var tp = floor_check.target_position
	tp.x = raycast_ahead * direction
	tp.y = raycast_down
	floor_check.target_position = tp
	
	# Actualizar RayCast del muro
	var wp = wall_check.target_position
	wp.x = raycast_ahead_wall * direction
	wp.y = 0
	wall_check.target_position = wp
	

	# Gravedad
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Movimiento
	if not is_dead:
		if is_on_floor():
			velocity.x = speed * direction
		else:
			velocity.x = 0
	else:
		velocity.x = 0
		
	update_animation()
	move_and_slide()

	# Detectar borde
	if is_on_floor() and (not floor_check.is_colliding() or wall_check.is_colliding()) and flip_timer <= 0.0:
		direction *= -1
		sprite.flip_h = direction == 1
		flip_timer = flip_debounce


func update_animation():
	# Si está muerto, no actualizamos ninguna otra animación
	if health <= 0:
		return

	if velocity.x != 0:
		if sprite.animation != "slime_idle":
			sprite.play("slime_idle")
	
# --- Sistema de daño ---
func take_damage(amount: int):
	if is_dead:
		return
		
		
	health -= amount
	print("Enemy HP:", health)
	
	if health <= 0:
		die() # Reproducir animación de muerte

func die():
	if is_dead:
		return
	is_dead = true
	sprite.play("dead")

	# Desactiva detección de daño
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)

	# Elimina colisiones físicas
	if fisic_hb:
		fisic_hb.set_deferred("disabled",true)
	
	gravity = 0

	velocity = Vector2.ZERO
	print("💀 Slime muerto, desactivando colisiones y daño")





func _on_animated_sprite_2d_animation_finished() -> void:
	print("✅ Animación terminada:", sprite.animation)
	if sprite.animation == "dead":
		print("💀 Slime eliminado")
		queue_free()
		
		
func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		print("💥 Enemy collided with player")
	if area.is_in_group("projectile"):
		print("💥 Enemy hit by bullet")
		take_damage(1)
		area.queue_free()
	
