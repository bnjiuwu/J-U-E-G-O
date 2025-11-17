extends PlayerProjectile
class_name Bullet


@export var max_distance: float = 600

var start_position: Vector2
var has_hit: bool = false


func _ready():
	start_position = global_position

	# Aseguramos señales
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	sprite.play("default")


func _physics_process(delta):
	if has_hit:
		return

	position += direction * speed * delta
	rotation = direction.angle()

	if global_position.distance_to(start_position) > max_distance:
		queue_free()


# ----------------------------------------
#   CUERPOS (Tilemap o enemigos CharacterBody2D)
# ----------------------------------------
func _on_body_entered(body: Node) -> void:
	if has_hit:
		return

	# Impacto con el mundo
	if body.is_in_group("world colition") or body is TileMapLayer:
		impact_effect()
		return

	# Impacto con enemigo (CUERPO)
	if body.is_in_group("enemy"):
		_apply_damage(body)
		impact_effect()
		return


# ----------------------------------------
#   ÁREAS (hitbox de enemigos con Area2D)
# ----------------------------------------
func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return

	if area.is_in_group("enemy"):
		_apply_damage(area)
		impact_effect()

# ----------------------------------------
#   Daño corregido (soporta hitboxes)
# ----------------------------------------
func _apply_damage(target):
	var receiver = target

	# Si el hitbox pertenece a un enemigo…
	if target is Area2D and target.get_parent().is_in_group("enemy"):
		if target.get_parent().has_method("take_damage"):
			receiver = target.get_parent()

	# Finalmente dañamos
	if receiver.has_method("take_damage"):
		receiver.take_damage(damage)


# ----------------------------------------
#   EFECTO DE IMPACTO → animación contacto + esperar animación
# ----------------------------------------
func impact_effect():
	has_hit = true
	col.disabled = true
	direction = Vector2.ZERO
	speed = 0

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("contact"):
		sprite.play("contact")
	else:
		# Si no existe la animación, simplemente destruye la bala
		queue_free()
		return

	await get_tree().process_frame
	await sprite.animation_finished

	queue_free()
