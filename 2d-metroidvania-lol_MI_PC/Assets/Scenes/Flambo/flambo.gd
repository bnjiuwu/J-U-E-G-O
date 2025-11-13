extends CharacterBody2D

## Script de Flambo, el compañero de Mondongo.
## Sigue al jugador con un 'lerp' suave, reacciona a su estado
## y tiene un movimiento de flote (onda).

# --- Variables Exportables ---
@export var mondongo: CharacterBody2D

@export_group("Ajustes de Seguimiento")
@export var offset_seguimiento: Vector2 = Vector2(45, -40) # Distancia (siempre positiva)
@export var velocidad_seguimiento: float = 5.0 

@export_group("Ajustes de Flote")
@export var amplitud_flote: float = 8.0 
@export var velocidad_flote: float = 4.0

# --- Nodos Internos (OnReady) ---
@onready var sprite_animado: AnimatedSprite2D = $AnimatedSprite2D
@onready var timer_enojo: Timer = $TimerEnfado

# --- Estados ---
enum Estado { QUIETO, ENOJADO, MUERTO }
var estado_actual: Estado = Estado.QUIETO

# --- Métodos de Godot ---

func _ready():
	if not is_instance_valid(mondongo):
		push_error("¡ERROR CRÍTICO EN FLAMBO! El nodo 'mondongo' NO FUE ASIGNADO.")
		set_physics_process(false)
		return
	
	# --- Conexión de Señales ---
	if mondongo.has_signal("roberto_fue_golpeado"):
		mondongo.roberto_fue_golpeado.connect(_on_roberto_fue_golpeado)
	else:
		push_warning("Flambo: 'mondongo' no tiene la señal 'roberto_fue_golpeado'.")
		
	if mondongo.has_signal("roberto_murio"):
		mondongo.roberto_murio.connect(_on_roberto_murio)
	else:
		push_warning("Flambo: 'mondongo' no tiene la señal 'roberto_murio'.")

	timer_enojo.one_shot = true
	timer_enojo.wait_time = 0.8
	timer_enojo.timeout.connect(_on_timer_enojo_timeout)
	
	# Colocación inicial instantánea (con la nueva lógica)
	var multiplicador_pos_inicial = -1 if mondongo.is_facing_right else 1
	var offset_volteado_inicial = Vector2(offset_seguimiento.x * multiplicador_pos_inicial, offset_seguimiento.y)
	global_position = mondongo.global_position + offset_volteado_inicial
	
	set_estado(Estado.QUIETO)


func _physics_process(delta: float):
	if not is_instance_valid(mondongo):
		return

	# --- 1. Obtener la dirección de Roberto ---
	var roberto_mira_derecha: bool = mondongo.is_facing_right
	
	# --- 2. Lógica de Volteo (Flip) del Sprite ---
	# Hacemos que Flambo MIRE en la misma dirección que Roberto
	if roberto_mira_derecha:
		sprite_animado.flip_h = false # Mirar a la derecha
	else:
		sprite_animado.flip_h = true # Mirar a la izquierda

	# --- 3. Lógica de Posición (¡AQUÍ ESTÁ EL CAMBIO!) ---
	# Hacemos que Flambo se POSICIONE en la espalda de Roberto
	
	var multiplicador_posicion_x: int
	if roberto_mira_derecha:
		# Si Roberto mira a la derecha, Flambo va a la izquierda (negativo)
		multiplicador_posicion_x = -1
	else:
		# Si Roberto mira a la izquierda, Flambo va a la derecha (positivo)
		multiplicador_posicion_x = 1
		
	# Aplicamos el offset de "espalda"
	var offset_volteado = Vector2(offset_seguimiento.x * multiplicador_posicion_x, offset_seguimiento.y)
	var posicion_objetivo_base = mondongo.global_position + offset_volteado
	
	# --- 4. Calcular el Flote ---
	var tiempo = Time.get_ticks_msec() / 1000.0
	var flote_vertical = sin(tiempo * velocidad_flote) * amplitud_flote
	
	# --- 5. Aplicar Flote a la Posición Objetivo ---
	var posicion_objetivo_final = posicion_objetivo_base + Vector2(0, flote_vertical)

	# --- 6. Lógica de Seguimiento Suave (Lerp) ---
	global_position = global_position.lerp(posicion_objetivo_final, velocidad_seguimiento * delta)


# --- Máquina de Estados (Sin cambios) ---

func set_estado(nuevo_estado: Estado):
	if estado_actual == nuevo_estado:
		return
	estado_actual = nuevo_estado
	
	match estado_actual:
		Estado.QUIETO:
			sprite_animado.play("idle")
		Estado.ENOJADO:
			sprite_animado.play("angry")
		Estado.MUERTO:
			sprite_animado.play("dead")

# --- Controladores de Señales (Sin cambios) ---

func _on_roberto_fue_golpeado():
	if estado_actual != Estado.MUERTO:
		set_estado(Estado.ENOJADO)
		timer_enojo.start()

func _on_roberto_murio():
	set_estado(Estado.MUERTO)

func _on_timer_enojo_timeout():
	if estado_actual != Estado.MUERTO:
		set_estado(Estado.QUIETO)
