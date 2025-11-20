extends Sprite2D
class_name Knob

@onready var parent: Node2D = $".."
var pressing: bool = false
var active_index: int = -1           # dedo que controla el joystick

@export var maxLength: float = 100.0
@export var deadzone: float = 10.0


func _ready() -> void:
	maxLength *= parent.scale.x


func _process(_delta: float) -> void:
	# El movimiento del knob lo manejamos SOLO en _input (touch/drag).
	# Aquí solo reseteamos cuando no hay dedo activo.
	if not pressing:
		global_position = parent.global_position
		parent.posVector = Vector2.ZERO

	# Calcular vector SIEMPRE, incluso cuando no se está presionando
	calculateVector()


func _input(event: InputEvent) -> void:
	# ----- TOQUES EN PANTALLA -----
	if event is InputEventScreenTouch:
		if event.pressed:
			# Tomamos el dedo que empieza cerca del joystick
			if event.position.distance_to(parent.global_position) <= maxLength * 1.3:
				active_index = event.index
				pressing = true
				_move_knob_to(event.position)
		else:
			# Si se levantó el dedo que usábamos, lo liberamos
			if event.index == active_index:
				active_index = -1
				pressing = false

	elif event is InputEventScreenDrag:
		# Solo seguimos al dedo que capturamos
		if event.index == active_index and pressing:
			_move_knob_to(event.position)

	# IMPORTANTE: ya NO usamos mouse aquí. En PC, con
	# "Emulate Touch From Mouse" activado, el mouse genera
	# ScreenTouch/ScreenDrag y esto igual funciona.


func _move_knob_to(pos: Vector2) -> void:
	var center: Vector2 = parent.global_position
	var dir: Vector2 = pos - center
	var len: float = dir.length()

	if len <= maxLength:
		global_position = pos
	else:
		global_position = center + dir.normalized() * maxLength


func calculateVector() -> void:
	var dx: float = global_position.x - parent.global_position.x
	var dy: float = global_position.y - parent.global_position.y

	# eje X
	if abs(dx) >= deadzone:
		parent.posVector.x = dx / maxLength
	else:
		parent.posVector.x = 0.0

	# eje Y
	if abs(dy) >= deadzone:
		parent.posVector.y = dy / maxLength
	else:
		parent.posVector.y = 0.0

	# ====== TUS INPUTS DISCRETOS (movimiento + mirar arriba) ======
	"""
	# Movimiento horizontal
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
	# Puedes dejarlo vacío si quieres, ya no es necesario
	pressing = true


func _on_button_button_up() -> void:
	pressing = false
	active_index = -1
