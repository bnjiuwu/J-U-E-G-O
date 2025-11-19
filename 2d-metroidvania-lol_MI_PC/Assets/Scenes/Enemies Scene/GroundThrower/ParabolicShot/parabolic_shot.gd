extends EnemyProjectile
class_name ParabolicShot

# Tiempo total que tarda en ir desde el enemigo hasta el jugador
@export var travel_time: float = 0.8
# Altura máxima del arco (en píxeles)
@export var arc_height: float = 80.0

var start_pos: Vector2
var target_pos: Vector2
var t: float = 0.0
var prev_pos: Vector2

func setup_parabola(target: Vector2) -> void:
	# Llamar a esto DESPUÉS de instanciar y antes de añadir a la escena.
	start_pos = global_position
	target_pos = target
	t = 0.0
	prev_pos = global_position


func _ready() -> void:
	# Llama al _ready de Projectile / EnemyProjectile (colisiones, anim, etc.)
	super._ready()
	if start_pos == Vector2.ZERO:
		start_pos = global_position
	prev_pos = start_pos


func _physics_process(delta: float) -> void:
	if has_impacted:
		return

	# Si por algún motivo no hay target, no hacemos nada
	if target_pos == Vector2.ZERO:
		return

	t += delta / travel_time

	# Llegó al final del recorrido → impacta
	if t >= 1.0:
		impact()
		return

	# Base lineal entre origen y destino
	var base := start_pos.lerp(target_pos, t)

	# Parabola 4t(1-t) → 0 → 1 → 0 (forma de ∩)
	var arc := 4.0 * t * (1.0 - t)
	# En Godot, y+ es hacia abajo. Si queremos “cuadrática negativa” (sube y baja),
	# restamos en Y para que primero suba:
	var y_offset := -arc * arc_height

	var new_pos := Vector2(base.x, base.y + y_offset)

	# Rotar el sprite según la velocidad
	var vel = (new_pos - prev_pos) / max(delta, 0.0001)
	if vel.length() > 0.1:
		rotation = vel.angle()

	prev_pos = new_pos
	global_position = new_pos
