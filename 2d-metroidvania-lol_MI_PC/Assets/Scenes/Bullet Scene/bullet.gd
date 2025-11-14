extends Area2D

@export var speed: float = 400
@export var max_distance: float = 600 # rango máximo de la bala
@export var damage: int = 20

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2

func _ready():
	start_position = global_position
	add_to_group("projectile")
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("area_entered", Callable(self, "_on_area_entered"))

func _physics_process(delta):
	position += direction * speed * delta
	rotation = direction.angle()

	# Si la bala viaja más de max_distance, desaparece
	if global_position.distance_to(start_position) > max_distance:
		queue_free()
	

func _on_body_entered(body: Node) -> void:
	if _apply_damage(body):
		queue_free()
		return
	if body.is_in_group("world colition"):
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if _apply_damage(area):
		queue_free()

func _apply_damage(target: Node) -> bool:
	if target == null:
		return false
	if target == self:
		return false

	if target.is_in_group("enemy"):
		if target.has_method("take_damage"):
			target.take_damage(damage)
			return true
		var parent := target.get_parent()
		if parent and parent.has_method("take_damage"):
			parent.take_damage(damage)
			return true
	elif target.has_method("take_damage"):
		target.take_damage(damage)
		return true
	elif target is Area2D:
		var maybe_parent := target.get_parent()
		if maybe_parent and maybe_parent.has_method("take_damage"):
			maybe_parent.take_damage(damage)
			return true
	return false
