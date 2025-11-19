extends Area2D

@export var speed: float = 600.0
@export var damage: int = 50 # ¡Hace bastante daño!

var direction: Vector2 = Vector2.RIGHT

func _ready():
	# Si la bala sale de la pantalla, se autodestruye
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	
	# Por seguridad, se destruye sola a los 5 segundos si no salió de pantalla
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _physics_process(delta):
	position += direction * speed * delta

func set_direction(new_dir: Vector2):
	direction = new_dir
	# Girar el sprite según el ángulo
	rotation = direction.angle() 
	# O usa flip_h si prefieres no rotar el sprite completo
