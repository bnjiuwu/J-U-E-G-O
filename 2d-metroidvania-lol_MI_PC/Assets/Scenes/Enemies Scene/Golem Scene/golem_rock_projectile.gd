extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: int = 5
@export var lifetime: float = 4.0

@onready var _sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var _shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready():
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	if _sprite and _sprite.texture == null:
		# Create a simple 1x1 white texture and scale the sprite
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var tex := ImageTexture.create_from_image(img)
		_sprite.texture = tex
		_sprite.scale = Vector2(6, 6)

func initialize(vel: Vector2, dmg: int) -> void:
	velocity = vel
	damage = dmg

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# Damage player and destroy on hit
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	# Stop on any solid (TileMap or PhysicsBody)
	if body is PhysicsBody2D and not body.is_in_group("enemy"):
		queue_free()
