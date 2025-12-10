extends Area2D
class_name Projectile

@export var speed: float = 1000.0
@export var damage: int = 1
@export var lifetime: float = 1.5
@export var direction: Vector2 = Vector2.RIGHT
@export var hit_on_contact: bool = true
@export var destroy_after_contact: bool = true

var velocity: Vector2
var alive_time: float = 0.0
var has_impacted: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D   # <- muy importante


func _ready() -> void:
	velocity = direction.normalized() * speed

	if sprite:
		sprite.play("default")
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if has_impacted:
		return

	position += velocity * delta

	alive_time += delta
	if alive_time >= lifetime and not has_impacted:
		impact()


func _on_area_entered(area: Area2D) -> void:
	if has_impacted:
		return

	_apply_damage(area)
	if hit_on_contact:
		impact()


func _on_body_entered(body: Node) -> void:
	if has_impacted:
		return

	_apply_damage(body)
	if hit_on_contact:
		impact()


func _apply_damage(target):
	# implementación base vacía; EnemyProjectile la sobreescribe
	if target.has_method("take_damage"):
		target.take_damage(damage)


func _disable_collision() -> void:
	# desactivar TODA colisión del proyectil
	if col:
		col.disabled = true
	# desactivar el Area2D en sí
	monitoring = false
	monitorable = false


func impact() -> void:
	if has_impacted:
		return

	has_impacted = true
	velocity = Vector2.ZERO

	_disable_collision()  # 🔥 AQUÍ SE DESACTIVA LA COLISIÓN PARA SIEMPRE

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("contact"):
		sprite.play("contact")
	else:
		queue_free()


func _on_animation_finished() -> void:
	if has_impacted and destroy_after_contact:
		queue_free()

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	velocity = direction * speed
	rotation = direction.angle()
