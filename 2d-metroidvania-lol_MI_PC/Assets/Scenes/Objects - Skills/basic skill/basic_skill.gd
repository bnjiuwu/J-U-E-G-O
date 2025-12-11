extends PlayerProjectile
class_name Skill

@export var max_distance: float = 600
var start_position: Vector2

func _ready():
	super._ready()
	start_position = global_position

	if sprite:
		sprite.play("default")

func _physics_process(delta):
	if has_impacted:
		return

	position += direction * speed * delta
	rotation = direction.angle()

	if global_position.distance_to(start_position) > max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("world colition") or body is TileMapLayer:
		impact()
		return

	if body.is_in_group("enemy"):
		if apply_damage(body):
			impact()

func _on_area_entered(area: Area2D) -> void:
	if apply_damage(area):
		impact()
