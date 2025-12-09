extends Area2D
class_name PencilRain

@export var lifetime: float = 1.0
@export var damage: int = 20
@export var fall_speed: float = 260.0

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer: Timer = $Timer

func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if timer:
		timer.one_shot = true
		timer.wait_time = lifetime
		timer.timeout.connect(queue_free)
		timer.start()
	if animation:
		animation.play("rain")
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
