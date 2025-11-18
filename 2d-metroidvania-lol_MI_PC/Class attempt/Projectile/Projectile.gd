extends Area2D
class_name Projectile

@export var speed: float = 300.0
@export var damage: int = 1
@export var lifetime: float = 1.5
@export var direction: Vector2 = Vector2.RIGHT
@export var hit_on_contact: bool = true   # si desaparece al impacto
@export var destroy_after_contact: bool = true


var velocity: Vector2
var alive_time: float = 0.0
var has_impacted: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D
@onready var area: Area2D = self


func _ready() -> void:
	velocity = direction.normalized() * speed

	# Animación inicial
	if sprite:
		sprite.play("default")
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)

	# Conexiones de colisión
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if has_impacted:
		return  # no moverse mientras reproduce la animación contacto

	position += velocity * delta

	alive_time += delta
	if alive_time >= lifetime:
		impact()  # si expira, también reproduce animación contacto


func _on_area_entered(area: Area2D) -> void:
	_apply_damage(area)
	if hit_on_contact:
		impact()


func _on_body_entered(body: Node) -> void:
	_apply_damage(body)
	if hit_on_contact:
		impact()


func impact() -> void:
	if has_impacted:
		return
	has_impacted = true

	velocity = Vector2.ZERO  # detener movimiento
	_disable_collision() # <--- ESTA LÍNEA ES LA IMPORTANTE

	if sprite and sprite.sprite_frames.has_animation("contact"):
		sprite.play("contact")
	else:
		queue_free()  # si no existe, destruir directo


func _on_animation_finished() -> void:
	if has_impacted and destroy_after_contact:
		queue_free()


func _apply_damage(target):
	if target.has_method("take_damage"):
		target.take_damage(damage)

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	velocity = direction * speed
	rotation = direction.angle()

func _disable_collision():
	if area and area.monitoring:
		area.monitoring = false
		area.monitorable = false
