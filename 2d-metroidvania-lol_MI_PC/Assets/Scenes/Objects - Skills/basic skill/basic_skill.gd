extends PlayerProjectile
class_name Skill

@export var max_distance: float = 600
var start_position: Vector2

func _ready():
	start_position = global_position

	if sprite:
		sprite.play("default")

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _physics_process(delta):
	position += direction * speed * delta
	rotation = direction.angle()

	if global_position.distance_to(start_position) > max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# atraviesa mapa
	if body.is_in_group("world colition") or body is TileMapLayer:
		return

	# ignora cuerpo de enemigo (evita daño doble)
	if body.is_in_group("enemy"):
		return

func _on_area_entered(area: Area2D) -> void:
	# ✅ pasar el Area2D directo
	# PlayerProjectile resolverá al padre enemigo
	apply_damage(area)
