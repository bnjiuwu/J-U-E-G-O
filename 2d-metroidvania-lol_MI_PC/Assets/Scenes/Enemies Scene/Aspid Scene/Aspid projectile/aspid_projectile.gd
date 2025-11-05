extends Area2D

# --- CONFIGURABLES ---
@export var speed: float = 150.0
@export var damage: int = 40
@export var lifetime: float = 2.0
var direction: Vector2 = Vector2.RIGHT

# --- ONREADY ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D

# --- ESTADO ---
var time_alive: float = 0.0

# --- INICIO ---
func _ready():
	add_to_group("enemy_projectile")
	sprite.play("default")
	rotation = direction.angle()

# --- MOVIMIENTO ---
func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	time_alive += delta
	if time_alive > lifetime:
		queue_free()

# --- COLISIONES (cuerpos) ---
func _on_body_entered(body: Node) -> void:
	_hit(body)

# --- COLISIONES (áreas) ---
func _on_area_entered(area: Area2D) -> void:
	_hit(area)

# --- LÓGICA DE IMPACTO ---
func _hit(target: Node) -> void:
	# Solo afecta al jugador o sus habilidades
	if target.is_in_group("player") and "take_damage" in target:
		target.take_damage(damage)

	# Pequeña “muerte” visual del proyectil
	if col:
		col.disabled = true
	modulate = Color(1, 1, 1, 0.2)  # se desvanece visualmente
	await get_tree().create_timer(0.05).timeout
	queue_free()

# --- UTILIDAD ---
func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()
