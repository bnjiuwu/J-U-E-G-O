extends Area2D

@export var speed: float = 150.0
@export var damage: int = 40
@export var lifetime: float = 2.0
var direction: Vector2 = Vector2.RIGHT

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D

func _ready():
	# brillo azul sencillo (aditivo)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	self.modulate = Color(0.4, 0.7, 1.0, 1.0) # celeste-azul
	# autodestroy
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()

func _physics_process(delta):
	global_position += direction * speed * delta
	sprite.play("default")
	

# Colisiones (con cuerpos o áreas)
func _on_body_entered(body: Node) -> void:
	_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_hit(area)

func _hit(target: Node) -> void:
	# Si quieres aplicar daño real al player:
	if target.is_in_group("player") and "take_damage" in target:
		target.take_damage(damage)
	# “Explosión” mínima: desactiva y muere
	if col: col.disabled = true
	hide()
	queue_free()
