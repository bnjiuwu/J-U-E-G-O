extends Node2D
class_name CaseItem

@export var duration: float
@onready var timer: Timer = $Timer
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Asegura configuración del timer
	timer.one_shot = true
	timer.wait_time = duration

# --- API pública ---
func apply_to(player: Node) -> void:
	# Lógica común si quieres (opcional)
	_on_apply(player)

	timer.start()
	timer.timeout.connect(func():_on_expire(player), CONNECT_ONE_SHOT)
# --- Overridable ---
func _on_apply(player: Node) -> void:
	pass
func _on_expire(player: Node) -> void:
	pass
