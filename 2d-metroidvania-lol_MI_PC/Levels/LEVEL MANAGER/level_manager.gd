# res://Scripts/level_manager.gd
extends Node2D
class_name LevelManager

const ROULETTE_COOLDOWN := 30.0
const ATTACK_COUNTDOWN := 3

var _roulette_active: bool = false
var _roulette_pending: bool = false
var _roulette_cooldown_timer: float = 0.0

@onready var _attack_notice: Label = $CanvasLayer/AttackNotice

@export var niveles: Array[PackedScene] = []
@export_file("*.tscn") var fallback_scene: String = "res://Assets/Scenes/Menu/menu.tscn"

# --- RUULETA ---
@export var roulette_scene: PackedScene
var _roulette_instance: Node = null
@onready var _roulette_layer: Node = $CanvasLayer/RouletteLayer

var _nivel_actual: int = 1
var _nivel_instanciado: Node = null

@onready var _loading_screen: Control = $CanvasLayer/LoadingScreen

var _cargando: bool = false
var _nivel_path_cargando: String = ""
var _progreso := [0.0]

var _min_display_time := 0.5
var _display_time := 0.0

# --- FREEZE ---
var _frozen_player: Node = null
var _prev_player_process: bool = false
var _prev_player_physics: bool = false

func _ready() -> void:
	print("🧪 LevelManager ve matchId:", Network.matchId)

	if Network and not Network.mensaje_recibido.is_connected(_on_network_message):
		Network.mensaje_recibido.connect(_on_network_message)
		
	print("level_manager listo")
	add_to_group("level_manager") # útil por si quieres llamarlo por grupo

	if niveles.is_empty():
		push_error("No hay niveles asignados en 'niveles'.")
		return

	if _loading_screen == null:
		push_error("No encontré CanvasLayer/LoadingScreen.")
	else:
		_loading_screen.visible = false

	# Si no existe RouletteLayer, no crashea, pero avisa
	if _roulette_layer == null:
		push_warning("No encontré CanvasLayer/RouletteLayer. La ruleta se agregará al CanvasLayer.")

	_cargar_nivel_async(_nivel_actual)


func _process(delta: float) -> void:
	# --- cooldown de ruleta SIEMPRE ---
	if _roulette_cooldown_timer > 0.0:
		_roulette_cooldown_timer = max(0.0, _roulette_cooldown_timer - delta)

	# --- tu lógica de carga ---
	if not _cargando:
		return

	_display_time += delta

	var status := ResourceLoader.load_threaded_get_status(_nivel_path_cargando, _progreso)

	print("progreso carga: ", _progreso[0])

	if is_instance_valid(_loading_screen):
		_loading_screen.call("set_progress", _progreso[0])

	match status:
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
			pass
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
			push_error("Falló la carga del nivel: %s" % _nivel_path_cargando)
			_cargando = false
			_ocultar_pantalla_carga()
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			if _display_time < _min_display_time:
				return

			var scene_res: PackedScene = ResourceLoader.load_threaded_get(_nivel_path_cargando)
			if scene_res:
				_instanciar_nivel(scene_res)
			else:
				push_error("No se pudo obtener PackedScene de %s" % _nivel_path_cargando)

			_cargando = false
			_nivel_path_cargando = ""
			_ocultar_pantalla_carga()

func _show_attack_countdown() -> void:
	if not is_instance_valid(_attack_notice):
		return

	_attack_notice.visible = true

	for i in range(ATTACK_COUNTDOWN, 0, -1):
		_attack_notice.text = "ATAQUE RECIBIDO\nRuleta en %d..." % i
		await get_tree().create_timer(1.0).timeout

	_attack_notice.visible = false


func _cargar_nivel_async(numero_nivel: int) -> void:
	if numero_nivel < 1 or numero_nivel > niveles.size():
		push_error("Número de nivel fuera de rango: %d" % numero_nivel)
		if numero_nivel > niveles.size():
			_handle_all_levels_complete()
		return

	_nivel_actual = numero_nivel
	_eliminar_nivel()

	_mostrar_pantalla_carga()
	_display_time = 0.0

	var packed: PackedScene = niveles[numero_nivel - 1]
	_nivel_path_cargando = packed.resource_path
	print("Cargando nivel path: ", _nivel_path_cargando)

	if _nivel_path_cargando == "":
		push_error("El PackedScene del nivel %d no tiene resource_path válido." % numero_nivel)
		_ocultar_pantalla_carga()
		return

	_progreso[0] = 0.0
	_cargando = true

	var err := ResourceLoader.load_threaded_request(_nivel_path_cargando)
	if err != OK:
		push_error("No se pudo iniciar load_threaded_request: %s" % _nivel_path_cargando)
		_cargando = false
		_ocultar_pantalla_carga()


func request_next_level() -> void:
	var siguiente := _nivel_actual + 1
	if siguiente > niveles.size():
		_handle_all_levels_complete()
		return
	_cargar_nivel_async(siguiente)


func request_level(index: int) -> void:
	_cargar_nivel_async(index)


func _instanciar_nivel(packed: PackedScene) -> void:
	_nivel_instanciado = packed.instantiate()
	add_child(_nivel_instanciado)

	# ✅ importante: esperar 1 frame para que el player se registre en grupos
	await get_tree().process_frame

	# buscar player
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("No se encontró ningún nodo en el grupo 'player'.")
		return

	# ✅ conectar muerte seguro (si agregaste esta función)
	if has_method("_connect_player_signals"):
		_connect_player_signals(player)

	# conectar fuentes de ruleta del nivel (si aún las usas)
	if has_method("_wire_roulette_sources"):
		_wire_roulette_sources(player)


func _eliminar_nivel() -> void:
	if is_instance_valid(_nivel_instanciado):
		_nivel_instanciado.queue_free()
		_nivel_instanciado = null


func _reiniciar_nivel() -> void:
	_cargar_nivel_async(_nivel_actual)


func _mostrar_pantalla_carga() -> void:
	if is_instance_valid(_loading_screen):
		_loading_screen.visible = true
		_loading_screen.call("set_progress", 0.0)


func _ocultar_pantalla_carga() -> void:
	if is_instance_valid(_loading_screen):
		_loading_screen.visible = false


func _handle_all_levels_complete() -> void:
	print("✅ Todos los niveles han sido completados")
	if fallback_scene.is_empty():
		return
	var tree := get_tree()
	if tree:
		tree.change_scene_to_file(fallback_scene)

# =========================================================
# ===================== RULETA API ========================
# =========================================================
func _on_source_request_roulette(tipo: String, player: Node) -> void:
	# no uses el player directo, deja que el gateway valide todo
	trigger_roulette(tipo, 0, false)

func request_roulette(tipo: String = "") -> void:
	trigger_roulette(tipo, 0, false)

func show_roulette(player: Node, tipo: String = "") -> void:
	if roulette_scene == null:
		push_warning("roulette_scene no asignada en LevelManager.")
		return

	# Evitar abrir ruleta durante carga de nivel
	if _cargando:
		return

	# --- BLOQUEO anti-spam ---
	if _roulette_active or _roulette_pending or _roulette_cooldown_timer > 0.0:
		print("⏳ Ruleta ignorada (active/pending/cooldown): ", _roulette_cooldown_timer, "s")
		return

	_roulette_active = true
	_roulette_cooldown_timer = ROULETTE_COOLDOWN

	# eliminar instancia anterior si existe
	if is_instance_valid(_roulette_instance):
		_roulette_instance.queue_free()

	_roulette_instance = roulette_scene.instantiate()

	var parent_node: Node = _roulette_layer if is_instance_valid(_roulette_layer) else $CanvasLayer
	parent_node.add_child(_roulette_instance)

	# asignar player
	if "player" in _roulette_instance:
		_roulette_instance.player = player

	# pasar tipo si lo soporta (aunque no segmentes)
	if _roulette_instance.has_method("set_trigger"):
		_roulette_instance.set_trigger(tipo)
	elif "trigger_type" in _roulette_instance:
		_roulette_instance.trigger_type = tipo

	# ✅ UI viva en pausa
	if is_instance_valid(_roulette_layer):
		_roulette_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_roulette_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# ✅ congelar juego ya
	_set_game_frozen(true)

	# cuando se cierre/destruya la ruleta → liberar pausa
	_roulette_instance.tree_exited.connect(func():
		_roulette_instance = null
		_roulette_active = false
		_set_game_frozen(false)
	, CONNECT_ONE_SHOT)

	# iniciar spin
	if _roulette_instance.has_method("start_spin"):
		_roulette_instance.start_spin()



func recibir_ataque(dmg: int) -> void:
	trigger_roulette("ataque", dmg, true)
		
func _wire_roulette_sources(player: Node) -> void:
	var sources := get_tree().get_nodes_in_group("roulette_source")
	for s in sources:
		if not is_instance_valid(s):
			continue

		# asegurar que pertenecen al nivel actual
		if _nivel_instanciado and not _nivel_instanciado.is_ancestor_of(s):
			continue

		if s.has_signal("request_roulette"):
			# conecta señal con tipo
			var cb := Callable(self, "_on_source_request_roulette").bind(player)

			if not s.request_roulette.is_connected(cb):
				s.request_roulette.connect(cb)
				
func _on_network_message(msg: String) -> void:
	var data = JSON.parse_string(msg)
	if typeof(data) != TYPE_DICTIONARY:
		return

	if str(data.get("event", "")) != "receive-game-data":
		return

	var payload = data.get("data", {}).get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		return

	if payload.get("type", "") == "attack":
		var dmg := int(payload.get("damage", 5))
		trigger_roulette("ataque", dmg, true)  # ✅ countdown + daño

func _set_game_frozen(freeze: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")

	if freeze:
		# Pausa global
		get_tree().paused = true

		# Apagado manual del player (backup por si algo está en Always)
		if is_instance_valid(player):
			_frozen_player = player
			_prev_player_process = player.is_processing()
			_prev_player_physics = player.is_physics_processing()

			player.set_process(false)
			player.set_physics_process(false)
			player.set_process_input(false)

	else:
		get_tree().paused = false

		if is_instance_valid(_frozen_player):
			_frozen_player.set_process(_prev_player_process)
			_frozen_player.set_physics_process(_prev_player_physics)
			_frozen_player.set_process_input(true)

		_frozen_player = null
func _connect_player_signals(player: Node) -> void:
	if not player.has_signal("died"):
		return

	var cb := Callable(self, "_on_player_died")
	if player.died.is_connected(cb):
		player.died.disconnect(cb)

	player.died.connect(cb)


func _on_player_died() -> void:
	# prevenir caos si muere mientras ruleta está activa o mientras cargamos
	_force_cleanup_roulette()

	if _cargando:
		return

	# reinicio seguro fuera del frame actual
	call_deferred("_reiniciar_nivel")


func _force_cleanup_roulette() -> void:
	# Quita pausa siempre
	_set_game_frozen(false)

	_roulette_active = false
	_roulette_pending = false

	if is_instance_valid(_roulette_instance):
		_roulette_instance.queue_free()
		_roulette_instance = null
func trigger_roulette(tipo: String = "", dmg: int = 0, use_countdown: bool = false) -> void:
	# buscar player
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("No hay player para activar ruleta.")
		return

	# aplicar daño si corresponde
	#if dmg > 0 and player.has_method("take_damage"):
	#	player.take_damage(dmg)

	# bloquear spam
	if _roulette_active or _roulette_pending or _roulette_cooldown_timer > 0.0:
		print("⏳ Ruleta bloqueada (active/pending/cooldown).")
		return

	_roulette_pending = true

	# countdown opcional
	if use_countdown:
		await _show_attack_countdown()

	_roulette_pending = false

	# ✅ único lugar que llama show_roulette
	show_roulette(player, tipo)
