extends PlayerProjectile
class_name Bullet

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

func _on_body_entered(body: Node) -> void:
	if has_hit:
		return

	if body.is_in_group("world colition") or body is TileMapLayer:
		impact_effect()
		return

	if body.is_in_group("enemy") and apply_damage(body):
		impact_effect()

func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return

	# Si el hitbox pertenece a enemigo, igual funcionará
	if area.is_in_group("enemy") and apply_damage(area):
		impact_effect()

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
