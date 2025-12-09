extends Sprite2D
class_name Knob

const H_THRESHOLD := 0.25
const LOOK_THRESHOLD := -0.5

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
		parent.pressing = false

	# Calcular vector SIEMPRE, incluso cuando no se está presionando
	calculateVector()


func _input(event: InputEvent) -> void:
	# ----- TOQUES EN PANTALLA -----
	if event is InputEventScreenTouch:
		if event.pressed:
			# Tomamos el dedo que empieza cerca del joystick
			if event.position.distance_to(parent.global_position) <= maxLength * 1.3:
				active_index = event.index
				_update_pressing(true)
				_move_knob_to(event.position)
		else:
			# Si se levantó el dedo que usábamos, lo liberamos
			if event.index == active_index:
				active_index = -1
				_update_pressing(false)

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
	_apply_discrete_inputs()

func _on_button_button_down() -> void:
	_update_pressing(true)


func _on_button_button_up() -> void:
	active_index = -1
	_update_pressing(false)

func _update_pressing(state: bool) -> void:
	pressing = state
	if parent:
		parent.pressing = state
	if not state:
		_release_inputs()

func _apply_discrete_inputs() -> void:
	if not pressing:
		return

	var x: float = parent.posVector.x
	var y: float = parent.posVector.y
	if x < -H_THRESHOLD:
		Input.action_press("move_left", clamp(-x, 0.0, 1.0))
		Input.action_release("move_right")
	elif x > H_THRESHOLD:
		Input.action_press("move_right", clamp(x, 0.0, 1.0))
		Input.action_release("move_left")
	else:
		_release_horizontal_inputs()

	if y < LOOK_THRESHOLD:
		Input.action_press("look_up", clamp(-y, 0.0, 1.0))
	else:
		Input.action_release("look_up")

func _release_horizontal_inputs() -> void:
	if Input.is_action_pressed("move_left"):
		Input.action_release("move_left")
	if Input.is_action_pressed("move_right"):
		Input.action_release("move_right")

func _release_inputs() -> void:
	_release_horizontal_inputs()
	if Input.is_action_pressed("look_up"):
		Input.action_release("look_up")
