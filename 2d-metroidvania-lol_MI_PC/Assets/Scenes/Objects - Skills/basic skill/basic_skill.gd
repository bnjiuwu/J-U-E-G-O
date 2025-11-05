extends Area2D

@export var speed: float = 300
@export var max_distance: float = 600 # rango máximo de la bala
@export var damage: int = 70

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2

func _ready():
	start_position = global_position
	add_to_group("Skills")
	connect("body_entered", Callable(self, "_on_body_entered")) # detectar cuerpos

func _physics_process(delta):
	position += direction * speed * delta
	rotation = direction.angle()

	# Si la bala viaja más de max_distance, desaparece
	if global_position.distance_to(start_position) > max_distance:
		queue_free()
	

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("world colition"):
		print("💥 Bala chocó con pared")
		queue_free()
