extends EnemyGround
class_name Slime

@export var speed: float = 50

# --- VARIABLES FALTANTES (AGREGADAS) ---
# 1. Variables para controlar el tiempo de giro
var flip_timer: float = 0.0
var flip_debounce: float = 0.5 # Tiempo (segundos) que espera antes de poder girar de nuevo

# 2. Variables para definir el LARGO de los rayos (distancias)
@export var raycast_ahead: float = 20.0      # Qué tan lejos mira hacia adelante el suelo
@export var raycast_down: float = 20.0       # Qué tan profundo mira el suelo
@export var raycast_ahead_wall: float = 15.0 # Qué tan lejos detecta la pared

# 3. Referencia al colisionador físico
# Asegúrate de que tu nodo de colisión se llame "CollisionShape2D"
@onready var fisic_hb: CollisionShape2D = $CollisionShape2D 
# ---------------------------------------

var damage_modulate_timer: float = 0.05

@onready var wall_check: RayCast2D = $wall_check
@onready var floor_check: RayCast2D = $floor_check

func ground_behavior(delta):
	velocity.x = direction * speed

	if wall_check.is_colliding():
		flip_direction() # Asumo que esta función está en EnemyGround

	if floor_check and not floor_check.is_colliding() and is_on_floor():
		flip_direction()
		
	# Lógica del timer de giro
	if flip_timer > 0.0:
		flip_timer -= delta

	# Actualizar raycast de suelo (floor_check)
	var tp = floor_check.target_position
	tp.x = raycast_ahead * direction
	tp.y = raycast_down
	floor_check.target_position = tp
	
	# Actualizar RayCast del muro (wall_check)
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

	# Detectar borde y girar
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
	
	# --- ¡SEÑAL PARA FLAMBO! ---
	GlobalsSignals.enemy_defeated.emit()
	# ---------------------------

	# Desactiva detección de daño
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)

	# Elimina colisiones físicas
	if fisic_hb:
		fisic_hb.set_deferred("disabled", true)
	
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
		take_damage(area.damage) # Asegúrate que la bala tenga var damage
		area.queue_free()
	if area.is_in_group("Skills"):
		print("💥 Mago recibió impacto de habilidad")
		take_damage(area.damage)
		area.queue_free()
