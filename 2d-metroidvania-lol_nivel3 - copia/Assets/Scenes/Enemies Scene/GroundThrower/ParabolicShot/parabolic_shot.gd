extends EnemyProjectile
class_name ParabolicShot

@export var travel_time: float = 0.8
@export var arc_height: float = 80.0

var start_pos: Vector2
var target_pos: Vector2
var t: float = 0.0
var prev_pos: Vector2
var final_velocity: Vector2 = Vector2.ZERO  # velocidad con la que seguirá de largo


func setup_parabola(target: Vector2) -> void:
	start_pos = global_position
	target_pos = target
	t = 0.0
	prev_pos = global_position


func _ready() -> void:
	super._ready()
	if start_pos == Vector2.ZERO:
		start_pos = global_position
	prev_pos = start_pos


func _physics_process(delta: float) -> void:
	if has_impacted:
		return

	# Si no tenemos objetivo, no hacemos nada
	if target_pos == Vector2.ZERO:
		return

	t += delta / travel_time

	if t < 1.0:
		# ===== TRAMO PARABÓLICO =====
		var base := start_pos.lerp(target_pos, t)
		var arc := 4.0 * t * (1.0 - t)
		var y_offset := -arc * arc_height   # negativa => primero sube, luego baja

		var new_pos := Vector2(base.x, base.y + y_offset)

		# Velocidad instantánea
		var vel = (new_pos - prev_pos) / max(delta, 0.0001)
		final_velocity = vel                # guardamos la última velocidad

		if vel.length() > 0.1:
			rotation = vel.angle()

		prev_pos = new_pos
		global_position = new_pos

	else:
		# ===== YA PASÓ EL PUNTO DEL JUGADOR → SIGUE DE LARGO =====
		if final_velocity != Vector2.ZERO:
			global_position += final_velocity * delta
			rotation = final_velocity.angle()
		else:
			# fallback raro (por si algo salió mal)
			global_position += (target_pos - start_pos).normalized() * 200.0 * delta
