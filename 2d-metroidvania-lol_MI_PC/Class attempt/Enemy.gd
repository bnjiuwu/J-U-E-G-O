extends CharacterBody2D
class_name Enemy

@export var max_health: int = 3

var health: int
var is_dead: bool = false
var is_attacking: bool = false
var is_moving: bool = false
var direction: int = -1  # -1 izquierda, 1 derecha

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = get_node_or_null("Hitbox")

func _ready() -> void:
	health = max_health
	add_to_group("enemy")

	# Conectar hitbox si existe
	if hitbox:
		if not hitbox.area_entered.is_connected(_on_hitbox_area_entered):
			hitbox.area_entered.connect(_on_hitbox_area_entered)
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)

	# Conectar animación si existe
	if sprite and not sprite.animation_finished.is_connected(_on_animation_finished):
		sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	enemy_behavior(delta)
	update_animation()


# -------------------------
#  Para que los hijos lo sobreescriban
# -------------------------
func enemy_behavior(delta: float) -> void:
	pass


# -------------------------
#  Animaciones genéricas
# -------------------------
func update_animation() -> void:
	if not sprite:
		return

	if is_dead:
		if sprite.animation != "death":
			sprite.play("death")
		return

	if is_attacking:
		if not sprite.animation.begins_with("attack"):
			sprite.play("attack")
		return

	if is_moving:
		if sprite.animation != "walk":
			sprite.play("walk")
	else:
		if sprite.animation != "idle":
			sprite.play("idle")


func _on_animation_finished() -> void:
	# Si murió, al terminar death lo borramos
	if is_dead and sprite.animation == "death":
		queue_free()
		return

	# Si era animación de ataque, terminar estado
	if sprite.animation.begins_with("attack"):
		is_attacking = false


# -------------------------
#  Daño & muerte
# -------------------------
func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	if health <= 0:
		die()
	else:
		# feedback hit (opcional)
		modulate = Color(1, 0.4, 0.4)
		await get_tree().create_timer(0.05).timeout
		modulate = Color(1, 1, 1)


func die() -> void:
	if is_dead:
		return
	is_dead = true

	velocity = Vector2.ZERO
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		queue_free()


# -------------------------
#  Hitbox genérico
# -------------------------
func _on_hitbox_area_entered(area: Area2D) -> void:
	# Balas del jugador
	if area.is_in_group("projectile"):
		var dmg := 1
		if "damage" in area:
			dmg = area.damage
		take_damage(dmg)
		area.queue_free()

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Si quieres que choque con el player aquí (daño de contacto)
	if body.is_in_group("player"):
		# Ejemplo: el enemigo NO recibe daño, pero el player sí
		if "take_damage" in body:
			body.take_damage(10, global_position)
