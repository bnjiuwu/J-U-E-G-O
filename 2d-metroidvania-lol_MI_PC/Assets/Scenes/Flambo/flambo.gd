extends CharacterBody2D

## Script de Flambo: Guardaespaldas Automático

# --- Referencias ---
@export var mondongo: CharacterBody2D
@export var mini_flambo_scene: PackedScene 

# --- Configuración ---
@export_group("Comportamiento")
@export var offset_seguimiento: Vector2 = Vector2(45, -40) 
@export var velocidad_seguimiento: float = 5.0 
@export var meta_carga: int = 5

# --- Variables Internas ---
var enemigos_derrotados: int = 0
var esta_cargado: bool = false
var enemigos_en_rango: Array = [] # Lista de enemigos cercanos

# --- Nodos ---
@onready var sprite_animado: AnimatedSprite2D = $AnimatedSprite2D
@onready var rango_ataque: Area2D = $RangoAtaque # ¡Asegúrate de crear este nodo!
@onready var timer_enojo: Timer = $TimerEnfado

enum Estado { QUIETO, ENOJADO, MUERTO }
var estado_actual: Estado = Estado.QUIETO

func _ready():
	if not is_instance_valid(mondongo): return
	
	# Señales de Roberto
	if mondongo.has_signal("roberto_fue_golpeado"):
		mondongo.roberto_fue_golpeado.connect(_on_roberto_fue_golpeado)
	if mondongo.has_signal("roberto_murio"):
		mondongo.roberto_murio.connect(_on_roberto_murio)

	# Señal Global de muertes
	GlobalsSignals.enemy_defeated.connect(_on_enemy_defeated)
	
	# Señales de Detección (Los "Ojos" de Flambo)
	rango_ataque.body_entered.connect(_on_enemigo_entra_rango)
	rango_ataque.body_exited.connect(_on_enemigo_sale_rango)

	timer_enojo.timeout.connect(_on_timer_enojo_timeout)
	set_estado(Estado.QUIETO)

func _physics_process(delta: float):
	if not is_instance_valid(mondongo): return
	
	# --- Movimiento (Igual que antes) ---
	var lado = -1 if mondongo.is_facing_right else 1
	sprite_animado.flip_h = not mondongo.is_facing_right
	
	var objetivo = mondongo.global_position + Vector2(offset_seguimiento.x * lado, offset_seguimiento.y)
	var flote = sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 8.0
	objetivo.y += flote
	
	global_position = global_position.lerp(objetivo, velocidad_seguimiento * delta)

# --- LÓGICA DE COMBATE AUTOMÁTICO ---

func _on_enemy_defeated():
	if esta_cargado: return # Si ya está listo, no cuenta más
	
	enemigos_derrotados += 1
	print("Flambo: Carga ", enemigos_derrotados, "/", meta_carga)
	
	if enemigos_derrotados >= meta_carga:
		cargar_habilidad()

func cargar_habilidad():
	esta_cargado = true
	modulate = Color(1.5, 1.5, 0.5, 1) # Brillo amarillo
	print("🔥 Flambo CARGADO - Buscando objetivo...")
	
	# Apenas se carga, intenta disparar si ya hay alguien cerca
	intentar_disparo_automatico()

func _on_enemigo_entra_rango(body):
	if body.is_in_group("enemy") and body != self:
		enemigos_en_rango.append(body)
		# Si entra un enemigo y ya estábamos cargados -> FUEGO
		intentar_disparo_automatico()

func _on_enemigo_sale_rango(body):
	if body in enemigos_en_rango:
		enemigos_en_rango.erase(body)

func intentar_disparo_automatico():
	# Condiciones: Estar cargado Y tener al menos un enemigo cerca
	if not esta_cargado or enemigos_en_rango.is_empty():
		return
	
	# Validar que el enemigo sigue vivo (por si acaso)
	var objetivo = enemigos_en_rango[0]
	if not is_instance_valid(objetivo):
		enemigos_en_rango.remove_at(0)
		return

	# --- ¡DISPARO! ---
	disparar_a(objetivo)

func disparar_a(target):
	if not mini_flambo_scene: return
	
	var bala = mini_flambo_scene.instantiate()
	bala.global_position = global_position
	
	# Calcular dirección hacia el enemigo específico
	var direccion = (target.global_position - global_position).normalized()
	bala.set_direction(direccion) # Asumiendo que tu bala tiene este método
	
	get_tree().current_scene.add_child(bala)
	
	# Resetear
	esta_cargado = false
	enemigos_derrotados = 0
	modulate = Color(1, 1, 1, 1)
	print("🚀 Flambo disparó automáticamente a un enemigo!")

# --- Estados (Sin cambios) ---
func set_estado(nuevo):
	estado_actual = nuevo
	match nuevo:
		Estado.QUIETO: sprite_animado.play("idle")
		Estado.ENOJADO: sprite_animado.play("angry")
		Estado.MUERTO: sprite_animado.play("dead")

func _on_roberto_fue_golpeado():
	if estado_actual != Estado.MUERTO: 
		set_estado(Estado.ENOJADO)
		timer_enojo.start()

func _on_roberto_murio(): set_estado(Estado.MUERTO)
func _on_timer_enojo_timeout(): if estado_actual != Estado.MUERTO: set_estado(Estado.QUIETO)
