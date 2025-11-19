extends CharacterBody2D
class_name Enemy

@export var max_health: int = 3
@export var sprite_faces_right: bool = true  # solo usado por enemigos terrestres

var health: int
var is_dead: bool = false
var is_attacking: bool = false
var is_moving: bool = false
var direction: int = 1  # -1 izquierda, 1 derecha

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = get_node_or_null("Hitbox")
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")
@onready var n_health_bar: Label = get_node_or_null("HealthBarNumber")



func _process(delta: float) -> void:
	if n_health_bar:
		n_health_bar.text = str(health)
		
func _ready() -> void:
	health = max_health
	add_to_group("enemy")

	# señales de hitbox
	if hitbox:
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)

	# señales de animación
	if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)

	_update_health_bar()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	enemy_behavior(delta)
	update_animation()


# =====================================================
#          PARA SOBRESCRIBIR EN HIJOS
# =====================================================
func enemy_behavior(delta: float) -> void:
	pass


# =====================================================
#                 ANIMACIONES
# =====================================================
func update_animation() -> void:
	if not sprite:
		return

	if is_dead:
		sprite.play("death")
		return

	if is_attacking:
		sprite.play("attack")
		return

	if is_moving:
		sprite.play("walk")
	else:
		sprite.play("idle")


func _on_animation_finished() -> void:
	if is_dead and sprite.animation == "death":
		queue_free()
		return

	if sprite.animation.begins_with("attack"):
		is_attacking = false


# =====================================================
#                 DAÑO Y MUERTE
# =====================================================
func take_damage(amount: int):
	if is_dead:
		return

	health -= amount
	_update_health_bar()

	if health <= 0:
		die()
		return

	modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(0.05).timeout
	modulate = Color(1, 1, 1)


func die():
	is_dead = true
	velocity = Vector2.ZERO
	
	GlobalsSignals.enemy_defeated.emit()
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		queue_free()

	if health_bar:
		health_bar.visible = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("projectile"):
		if "damage" in area:
			take_damage(area.damage)
		area.queue_free()

	if area.is_in_group("Skills"):
		if "damage" in area:
			take_damage(area.damage)
		area.queue_free()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and "take_damage" in body:
		body.take_damage(10, global_position)



func _update_health_bar():
	if not health_bar:
		return
	health_bar.max_value = max_health
	health_bar.value = health
	# PARA VER LA BARRA SIEMPRE:
	health_bar.visible = true
