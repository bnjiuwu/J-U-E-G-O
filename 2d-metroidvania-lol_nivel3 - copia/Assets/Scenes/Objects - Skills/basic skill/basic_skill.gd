extends PlayerProjectile
class_name BasicSkillBullet

@export var max_distance: float = 600.0

var start_position: Vector2
var has_hit := false

func _ready() -> void:
	start_position = global_position

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if sprite:
		sprite.play("default")

	add_to_group("projectile")

func _physics_process(delta: float) -> void:
	if has_hit:
		return

	position += direction * speed * delta
	rotation = direction.angle()

	if global_position.distance_to(start_position) > max_distance:
		queue_free()

# --- CUERPOS (TileMap u otros CharacterBody2D) ---
func _on_body_entered(body: Node) -> void:
	if has_hit:
		return

	if body.is_in_group("world colition") or body is TileMapLayer:
		impact_effect()
		return

	if body.is_in_group("enemy") and _apply_damage(body):
		impact_effect()

# --- ÁREAS (hitboxes con Area2D) ---
func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return

	if _is_enemy_area(area) and _apply_damage(area):
		impact_effect()

# --- Daño genérico ---
func _apply_damage(target: Node) -> bool:
	if target == null or target == self:
		return false

	var receiver: Node = target
	if target is Area2D:
		var parent := target.get_parent()
		if parent and parent.is_in_group("enemy"):
			receiver = parent

	if receiver.is_in_group("enemy") and receiver.has_method("take_damage"):
		receiver.take_damage(damage)
		return true

	if receiver.has_method("take_damage"):
		receiver.take_damage(damage)
		return true

	return false

func _is_enemy_area(area: Area2D) -> bool:
	return area.is_in_group("enemy") or area.is_in_group("enemy_hitbox")

# --- Efecto de impacto ---
func impact_effect() -> void:
	has_hit = true
	col.disabled = true
	direction = Vector2.ZERO
	speed = 0.0

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("contact"):
		sprite.play("contact")
		await get_tree().process_frame
		await sprite.animation_finished

	queue_free()
