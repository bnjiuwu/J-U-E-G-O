extends Area2D

@export var speed: float = 150.0
@export var damage: int = 40
@export var lifetime: float = 2.0
var direction: Vector2 = Vector2.RIGHT
var has_hit: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D

func _ready():
	# Optional: automatically destroy after lifetime expires
	await get_tree().create_timer(lifetime).timeout
	if not has_hit:
		queue_free()

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()

func _physics_process(delta):
	if has_hit:
		return  # stop movement after hitting something
	
	global_position += direction * speed * delta
	sprite.play("default_purple")

# --- Collision Handlers ---
func _on_body_entered(body: Node) -> void:
	_hit(body)

func _on_area_entered(area: Area2D) -> void:
	_hit(area)

# --- Main Collision Logic ---
func _hit(target: Node) -> void:
	if has_hit:
		return
	has_hit = true
	col.disabled = true
	direction = Vector2.ZERO

	# --- Collision with environment ---
	if target.is_in_group("world colition") or target is TileMapLayer:
		print("💥 MAGIC BALL hit the wall")
		sprite.play("collition_contact")
		
		await sprite.animation_finished
		queue_free()
		return
	
	# --- Collision with player ---
	if target.is_in_group("player") and "take_damage" in target:
		target.take_damage(damage)
		sprite.play("collition_contact")
		
		await sprite.animation_finished
		queue_free()
		return
	
	# --- Default case (anything else) ---
	sprite.play("collition_contact")
	await sprite.animation_finished
	queue_free()
