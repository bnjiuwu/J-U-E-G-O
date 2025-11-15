extends Area2D

@export var speed: float = 400
@export var max_distance: float = 600
@export var damage: int = 5

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var has_hit: bool = false

@onready var sprite: AnimatedSprite2D = $animatedsprite2d
@onready var col: CollisionShape2D = $CollisionShape2D

func _ready():
	start_position = global_position
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))
	sprite.play("default")

func _physics_process(delta):
	if has_hit:
		return
	position += direction * speed * delta
	rotation = direction.angle()

	if global_position.distance_to(start_position) > max_distance:
		queue_free()

# --- CUERPOS (mundo o enemigos CharacterBody2D) ---
func _on_body_entered(body: Node) -> void:
	if has_hit:
		return

	if body.is_in_group("world colition") or body is TileMapLayer:
		impact_effect()
	elif body.is_in_group("enemy"):
		if "take_damage" in body:
			body.take_damage(damage)
		impact_effect()

# --- ÁREAS (enemigos con hitbox tipo Area2D) ---
func _on_area_entered(area: Area2D) -> void:
	if has_hit:
		return

	if area.is_in_group("enemy"):
		if "take_damage" in area:
			area.take_damage(damage)
		impact_effect()

# --- EFECTO DE IMPACTO ---
func impact_effect():
	has_hit = true
	col.disabled = true
	direction = Vector2.ZERO
	speed = 0

	sprite.play("contact")

	# Espera un frame para asegurar que el cambio de animación se actualice
	await get_tree().process_frame

	# Ahora espera a que termine la animación
	await sprite.animation_finished

	queue_free()
