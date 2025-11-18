extends EnemyGround
class_name Slime

@export var speed: float = 50

var damage_modulate_timer: float = 0.05

@onready var wall_check: RayCast2D = $wall_check
@onready var floor_check: RayCast2D = $floor_check

func ground_behavior(delta):
	velocity.x = direction * speed

	if wall_check.is_colliding():
		flip_direction()

	if floor_check and not floor_check.is_colliding() and is_on_floor():
		flip_direction()
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
	
	# --- ¡SEÑAL PARA FLAMBO! ---
	# La emitimos aquí para que cuente la baja inmediatamente
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
		take_damage(area.damage)
		area.queue_free()
	if area.is_in_group("Skills"):
		print("💥 Mago recibió impacto de bala")
		take_damage(area.damage)
		area.queue_free()
	
