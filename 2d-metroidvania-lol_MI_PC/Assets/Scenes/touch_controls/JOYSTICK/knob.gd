extends Sprite2D

@onready var parent = $".."
var pressing = false
@export var maxLength = 100
@export var deadzone = 10


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	maxLength *= parent.scale.x
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if pressing:
		var mouse_pos = get_global_mouse_position()
		if mouse_pos.distance_to(parent.global_position) <= maxLength:
			global_position = mouse_pos
		else:
			var angle = parent.global_position.angle_to_point(mouse_pos)
			global_position.x = parent.global_position.x + cos(angle) * maxLength
			global_position.y = parent.global_position.y + sin(angle) * maxLength
	else:
		# Al soltar, el knob vuelve inmediatamente al centro
		global_position = parent.global_position
		parent.posVector = Vector2.ZERO

	# Calcular vector siempre, incluso cuando no se está presionando
	calculateVector()
		
func calculateVector():
	var dx = global_position.x - parent.global_position.x
	var dy = global_position.y - parent.global_position.y

	# eje X
	if abs(dx) >= deadzone:
		parent.posVector.x = dx / maxLength
	else:
		parent.posVector.x = 0

	# eje Y
	if abs(dy) >= deadzone:
		parent.posVector.y = dy / maxLength
	else:
		parent.posVector.y = 0

	# Definir inputs discretos para Godot
	# Movimiento horizontal
	"""
	if parent.posVector.x < -0.2:
		Input.action_press("move_left")
		Input.action_release("move_right")
	elif parent.posVector.x > 0.2:
		Input.action_press("move_right")
		Input.action_release("move_left")
	else:
		Input.action_release("move_left")
		Input.action_release("move_right")

	# Mirar arriba (con margen de error para diagonal)
	if parent.posVector.y < -0.5:
		Input.action_press("look_up")
	else:
		Input.action_release("look_up")
		
	"""


func _on_button_button_down() -> void:
	pressing = true
	pass # Replace with function body.

func _on_button_button_up() -> void:
	pressing = false
	pass # Replace with function body.
