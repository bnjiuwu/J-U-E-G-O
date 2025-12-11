# res://Scripts/level_manager.gd
extends Node2D
class_name LevelManager

@export var niveles: Array[PackedScene] = []
@export_file("*.tscn") var fallback_scene: String = "res://Assets/Scenes/Menu/menu.tscn"

# ---------------- RUULETA ----------------
@export var roulette_scene: PackedScene
@onready var _roulette_layer: Node = $CanvasLayer/RouletteLayer
var _roulette_instance: Node = null

# anti-spam de ruleta
var _roulette_active: bool = false
var _roulette_pending: bool = false
var _roulette_cooldown_timer: float = 0.0
@export var roulette_cooldown_seconds: float = 20.0

# ---------------- MULTI: MUERTES / RESULTADOS ----------------
@export var max_deaths_before_loss: int = 5
var _deaths_in_match: int = 0
var _match_finished: bool = false

# UI opcional por grupos
# Asigna tus nodos (Label/Control) a estos grupos si quieres:
#  - "match_notification_ui"
#  - "death_menu"
#  - "victory_menu"
#  - "attack_countdown_ui"
#  - "death_counter_ui" (Label)
#  - "match_status_ui" (Label)

# ---------------- LOADING ----------------
var _nivel_actual: int = 1
var _nivel_instanciado: Node = null

@onready var _loading_screen: Control = $CanvasLayer/LoadingScreen

var _cargando: bool = false
var _nivel_path_cargando: String = ""
var _progreso := [0.0]

var _min_display_time := 0.5
var _display_time := 0.0

@onready var pause_menu := $CanvasLayer/PauseMenu
@onready var death_menu := $CanvasLayer/DeathMenu

signal multiplayer_defeat_reached
var _opponent_defeated_reported: bool = false
var _opponent_defeated: bool = false
var _boss_defeated_local: bool = false




func _check_victory_conditions() -> void:
	if _match_finished:
		return

	# Si ya no hay matchId, esto se considera soloplayer
	if not _is_multiplayer():
		if _boss_defeated_local:
			_handle_local_victory()
		return

	# Multi: requiere 1/2 + 2/2
	if _opponent_defeated and _boss_defeated_local:
		_handle_local_victory()

func _notify_opponent_defeated(payload: Dictionary) -> void:
	var rival_name := ""
	var rival_game := ""

	# Preferimos los datos cacheados en Network si los seteas desde el menú multi
	if Network:
		rival_name = str(Network.opponent_name)
		rival_game = str(Network.opponent_game_name)

	# Fallback si el payload trae algo útil
	if rival_name == "":
		rival_name = str(payload.get("playerName", ""))

	var txt := "El rival fue derrotado"
	if rival_name != "":
		txt = "%s fue derrotado" % rival_name
		if rival_game != "":
			txt += " | %s" % rival_game

	MatchNotificationss.show_notification(txt, 5.0)

func get_pause_menu() -> Node:
	return pause_menu

func get_death_menu() -> Node:
	return death_menu

func show_death(text: String = "¡HAS MUERTO!") -> void:
	if is_instance_valid(death_menu) and "multiplayer_mode" in death_menu:
		death_menu.show_death(text)
	else:
		push_warning("DeathMenu no válido o sin show_death().")
		
func toggle_pause() -> void:
	if is_instance_valid(pause_menu) and pause_menu.has_method("toggle_pause"):
		pause_menu.toggle_pause()
	else:
		push_warning("PauseMenu no válido o sin toggle_pause().")


func exit_to_main_menu_from_pause() -> void:
	# 1) Quitar pausa visual/engine si aplica
	if is_instance_valid(pause_menu) and pause_menu.has_method("force_close"):
		# si tu PauseMenu tiene un método para cerrar sin lógica extra
		pause_menu.force_close()
	elif is_instance_valid(pause_menu) and pause_menu.has_method("toggle_pause"):
		# fallback seguro
		if pause_menu.visible:
			pause_menu.toggle_pause()

	# 2) Si estoy en multijugador activo, esto cuenta como rendición
	if _is_multiplayer() and Network:
		_match_finished = true

		# ✅ enviar derrota explícita + cerrar instancia en servidor
		if Network.has_method("surrender_match"):
			Network.surrender_match("pause_exit")
		else:
			# fallback por si aún no agregas surrender_match()
			Network.send_game_payload({"type": "defeat", "reason": "pause_exit"})
			if Network.has_method("leave_match"):
				Network.leave_match("pause_exit")

		# ✅ cortar conexión al salir del modo online
		if Network.has_method("apagar"):
			Network.apagar()

	# 3) Volver al menú principal
	if fallback_scene != "":
		_mostrar_pantalla_carga()
		get_tree().change_scene_to_file(fallback_scene)


var is_multiplayer: bool = false

func _ready() -> void:
	print("level_manager listo")
	add_to_group("level_manager")

	if niveles.is_empty():
		push_error("No hay niveles asignados en 'niveles'.")
		return

	if _loading_screen:
		_loading_screen.visible = false
	else:
		push_error("No encontré CanvasLayer/LoadingScreen.")

	if _roulette_layer == null:
		push_warning("No encontré CanvasLayer/RouletteLayer. La ruleta se agregará al CanvasLayer.")

	if Network and str(Network.matchId) != "":
		is_multiplayer = true
		if not Network.mensaje_recibido.is_connected(_on_network_message):
			Network.mensaje_recibido.connect(_on_network_message)
		print("🎮 [LEVEL] LevelManager en modo MULTI. matchId =", Network.matchId)
	else:
		is_multiplayer = false
		print("🎮 [LEVEL] LevelManager en modo SOLO.")
	_cargar_nivel_async(_nivel_actual)


func _process(delta: float) -> void:
	# cooldown ruleta
	if _roulette_cooldown_timer > 0.0:
		_roulette_cooldown_timer = max(0.0, _roulette_cooldown_timer - delta)

	if not _cargando:
		return

	_display_time += delta
	var status := ResourceLoader.load_threaded_get_status(_nivel_path_cargando, _progreso)

	if is_instance_valid(_loading_screen):
		_loading_screen.call("set_progress", _progreso[0])

	match status:
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
			pass
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
			push_error("Fallo la carga del nivel: %s" % _nivel_path_cargando)
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

func request_restart_level() -> void:
	_reiniciar_nivel()


func _instanciar_nivel(packed: PackedScene) -> void:
	_nivel_instanciado = packed.instantiate()
	add_child(_nivel_instanciado)

	# buscar player
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		# en algunos niveles el player puede instanciarse un frame después
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_warning("No se encontró ningún nodo 'player' al instanciar nivel.")
		return

	# conectar muerte del player para multijugador
	_wire_player(player)

	# conectar boss del nivel
	_wire_boss_sources()

	# conectar fuentes de ruleta del nivel (cofres/triggers/etc)
	_wire_roulette_sources(player)

	# refrescar UI de match por si aplica
	_update_death_counter_ui()


func _eliminar_nivel() -> void:
	# limpiar estado de ruleta visible al cambiar nivel
	if is_instance_valid(_roulette_instance):
		_roulette_instance.queue_free()
		_roulette_instance = null
	_roulette_active = false
	_roulette_pending = false

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

	if _is_multiplayer() and Network and Network.has_method("leave_match"):
		Network.leave_match("levels_complete")

	if fallback_scene.is_empty():
		return

	var tree := get_tree()
	if tree:
		tree.change_scene_to_file(fallback_scene)


# =========================================================
# ===================== MULTI HELPERS =====================
# =========================================================

func _is_multiplayer() -> bool:
	return Network and str(Network.matchId) != ""
	
func _match_active() -> bool:
	return Network != null and str(Network.matchId) != "" and not _match_finished

func _wire_player(player: Node) -> void:
	# Tu Player emite "died"
	if player.has_signal("died"):
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)

func _on_player_died() -> void:
	# SP: menú inmediato
	if not _is_multiplayer():
		if is_instance_valid(death_menu) and death_menu.has_method("show_death"):
			death_menu.show_death("¡HAS MUERTO!")
		return

	# MP
	Network.death_count += 1
	print("💀 [MULTI] muertes:", Network.death_count, "/", Network.death_limit)

	_update_death_counter_ui()

	if Network.death_count >= Network.death_limit:
		if Network.has_method("send_game_payload"):
			Network.send_game_payload({
				"type": "defeat",
				"reason": "death_limit",
				"deaths": Network.death_count
			})

		multiplayer_defeat_reached.emit()
		if Network.has_signal("local_defeat"):
			Network.local_defeat.emit(Network.death_count)

		if is_instance_valid(death_menu) and death_menu.has_method("show_death"):
			death_menu.show_death("DERROTA: 5 MUERTES")
		return

	_reiniciar_nivel()



func _handle_local_loss() -> void:
	_match_finished = true
	print("❌ Derrota por muertes.")

	# Avisar al rival/servidor vía payload estándar
	if Network:
		Network.send_game_payload({
			"type": "defeat",
			"reason": "deaths",
			"count": _deaths_in_match
		})

	_show_death_menu()

func _handle_local_victory() -> void:
	if _match_finished:
		return
	_match_finished = true

	# 🔫 En lugar de enviar "victory", mandamos un ataque fuerte
	if Network and Network.matchId != "":
		Network.send_game_payload({
			"type": "attack",
			"damage": 60,          # daño grande, para que en el otro lado sea un ataque importante
			"source": "boss_clear"   # etiqueta opcional, por si quieres diferenciarlo en logs
		})

	# Esto es SOLO UI local, no afecta al servidor ni a otros juegos
	_notify_match_ended()


func _update_death_counter_ui() -> void:
	var lbl := get_tree().get_first_node_in_group("death_counter_ui")
	if lbl and lbl is Label:
		if _is_multiplayer() and Network:
			lbl.visible = true
			lbl.text = "Muertes: %d / %d" % [Network.death_count, Network.death_limit]
		else:
			lbl.visible = false


# =========================================================
# ===================== BOSS WIRING =======================
# =========================================================

func _wire_boss_sources() -> void:
	if _nivel_instanciado == null:
		return

	var bosses := get_tree().get_nodes_in_group("boss")
	for b in bosses:
		if not is_instance_valid(b):
			continue
		if not _nivel_instanciado.is_ancestor_of(b):
			continue

		# señal preferida
		if b.has_signal("boss_defeated"):
			if not b.boss_defeated.is_connected(_on_boss_defeated):
				b.boss_defeated.connect(_on_boss_defeated)

func _on_boss_defeated() -> void:
	_boss_defeated_local = true
	_check_victory_conditions()


# =========================================================
# ===================== NETWORK IN-GAME ===================
# =========================================================

func _on_network_message(msg: String) -> void:
	var data = JSON.parse_string(msg)
	if typeof(data) != TYPE_DICTIONARY:
		return

	var evento := str(data.get("event", ""))
	print("📡 [LEVEL_MANAGER] Evento:", evento, " | data:", data)

	# Eventos que nos interesan durante gameplay
	match evento:
		"close-match", "quit-match":
			_notify_opponent_disconnected(data) # pasamos data por si trae playerName
		"game-ended":
			_notify_match_ended()
		"receive-game-data":
			_handle_receive_game_data(data)

		_:
			pass

func _handle_receive_game_data(data: Dictionary) -> void:
	var payload = data.get("data", {}).get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		return

	var tipo := str(payload.get("type", payload.get("action", "")))

# Compatibilidad: si aún se envía close:true o tipo quit-match en payload,
# lo tratamos como cierre remoto
	if payload.get("close", false) == true or tipo == "quit-match":
		_notify_opponent_disconnected(data)
		return    
			  # cierra el WebSocket → deja de hacer ping
	match tipo:
		"loss", "defeat":
			_opponent_defeated = true

			var n := str(Network.opponent_name) if Network else ""
			var g := str(Network.opponent_game_name) if Network else ""

			var txt := "Rival derrotado (1/2)"
			if n != "" and g != "":
				txt = "Rival %s | %s fue derrotado (1/2)" % [n, g]
			elif n != "":
				txt = "Rival %s fue derrotado (1/2)" % n

			MatchNotificationss.show_notification(txt, 5.0)

			_check_victory_conditions()
			
			return

		"victory":
			# Opcional: solo informativo, ya no te mata automático
			var n := str(Network.opponent_name) if Network else ""
			if n != "":
				MatchNotificationss.show_notification("texto", 5.0)

			return

		"attack":
			var dmg := int(payload.get("damage", 5))
			recibir_ataque(dmg)
			return



func _notify_opponent_disconnected(data: Dictionary) -> void:
	var raw = data.get("data", {})
	var rival_name := str(raw.get("playerName", ""))

	if rival_name == "":
		rival_name = "Rival"

	print("🚪 [LEVEL] Rival desconectado / match cerrado. data:", raw)

	# 🟡 Notificación global (5s, manejado por tu autoload Notifications)
	MatchNotificationss.show_notification("⚠️ %s se desconectó. Volviendo a solo." % rival_name,5.0)

	# 🧹 Limpiar estado de match y apagar red
	if Network:
		# Limpia matchId, contador de muertes, etc.
		Network.reset_match_state()
		# Cierra completamente el WebSocket -> adiós pings y jugador "fantasma"
		Network.apagar()

	# 🔻 Bajar a modo singleplayer dentro del mismo nivel
	_downgrade_to_singleplayer()


func _downgrade_to_singleplayer() -> void:
	print("🔻 Cambiando a modo single-player (match terminado)")
	if Network:
		Network.reset_match_state()

	_update_death_counter_ui()

	
func _notify_match_ended() -> void:
	print("ℹ️ Match finalizado por servidor → pasar a soloplayer y cerrar conexión.")

	var txt := "Partida terminada"
	if Engine.has_singleton("MatchNotificationss"):
		MatchNotificationss.show_notification(txt, 5.0)
		

	# 2) Cerrar conexión WebSocket para liberar la instancia en el servidor
	if Network:
		if Network.has_method("reset_match_state"):
			Network.reset_match_state()
		if Network.has_method("apagar"):
			Network.apagar()

	# 3) Notificación visual durante 5s (ya manejado por el autoload)

# =========================================================
# ===================== RULETA API ========================
# =========================================================

# API única recomendada:
# - tipo: "ataque", "buff", etc
# - dmg: opcional
# - use_countdown: mostrar cuenta regresiva 3..2..1
func trigger_roulette(tipo: String = "", dmg: int = 0, use_countdown: bool = false) -> void:
	if _match_finished:
		return

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("No hay player para activar ruleta.")
		return

	# bloquear spam
	if _roulette_active or _roulette_pending or _roulette_cooldown_timer > 0.0:
		print("⏳ Ruleta bloqueada (active/pending/cooldown).")
		return

	_roulette_pending = true

	# countdown opcional
	if use_countdown:
		await _show_attack_countdown()

		# ✅ FIX CRÍTICO:
		# Re-adquirir player tras esperar, por si el nivel se reinició o el player murió
		player = get_tree().get_first_node_in_group("player")
		if player == null or not is_instance_valid(player):
			print("⚠️ Player inválido tras countdown → cancelo ruleta.")
			_roulette_pending = false
			return

	_roulette_pending = false

	show_roulette(player, tipo)

func recibir_ataque(dmg: int) -> void:
	# tu flujo anterior: daño + cuenta regresiva + ruleta
	# si quieres aplicar daño aquí, descomenta
	# var player := get_tree().get_first_node_in_group("player")
	# if player and player.has_method("take_damage"):
	#	player.take_damage(dmg)

	trigger_roulette("ataque", dmg, true)

func show_roulette(player: Node, tipo: String = "") -> void:
	if roulette_scene == null:
		push_warning("roulette_scene no asignada en LevelManager.")
		return

	# limpieza previa
	if is_instance_valid(_roulette_instance):
		_roulette_instance.queue_free()

	_roulette_instance = roulette_scene.instantiate()

	var parent_node: Node = _roulette_layer if is_instance_valid(_roulette_layer) else $CanvasLayer
	parent_node.add_child(_roulette_instance)

	# marcar estado
	_roulette_active = true
	_roulette_cooldown_timer = roulette_cooldown_seconds

	# pasar contexto si tu ruleta lo soporta
	if "player" in _roulette_instance:
		_roulette_instance.player = player
	if "tipo" in _roulette_instance:
		_roulette_instance.tipo = tipo

	# al cerrar, liberar flags
	_roulette_instance.tree_exited.connect(func():
		_roulette_instance = null
		_roulette_active = false
	, CONNECT_ONE_SHOT)

	# iniciar si existe
	if _roulette_instance.has_method("start_spin"):
		_roulette_instance.start_spin()

# Fuentes del nivel que pidan ruleta por señal
# Deben estar en grupo "roulette_source" y emitir:
# signal request_roulette
func _wire_roulette_sources(player: Node) -> void:
	var sources := get_tree().get_nodes_in_group("roulette_source")
	for s in sources:
		if not is_instance_valid(s):
			continue
		if _nivel_instanciado and not _nivel_instanciado.is_ancestor_of(s):
			continue

		if s.has_signal("request_roulette"):
			# conectamos a trigger_roulette para respetar cooldown
			var cb := func(tipo := ""):
				trigger_roulette(str(tipo), 0, false)

			# evita duplicados
			if not s.request_roulette.is_connected(cb):
				s.request_roulette.connect(cb)

# Cuenta regresiva 3s (opcional)
func _show_attack_countdown() -> void:
	var lbl := get_tree().get_first_node_in_group("attack_countdown_ui")
	if lbl and lbl is Label:
		lbl.visible = true
		for i in [3, 2, 1]:
			lbl.text = "Ruleta en %d..." % i
			await get_tree().create_timer(1.0).timeout
		lbl.visible = false
	else:
		# si no existe label, igual espera 3s
		await get_tree().create_timer(3.0).timeout

# Menús por grupos (no acoplan a tu estructura interna)
func _show_death_menu() -> void:
	var menu := get_tree().get_first_node_in_group("death_menu")
	if menu and menu is CanvasItem:
		menu.visible = true
		return

	# fallback por método del nivel
	if _nivel_instanciado and _nivel_instanciado.has_method("show_death_menu"):
		_nivel_instanciado.show_death_menu()
		return

	push_warning("No encontré death menu (grupo 'death_menu' o método show_death_menu).")

func _show_victory_menu() -> void:
	var menu := get_tree().get_first_node_in_group("victory_menu")
	if menu and menu is CanvasItem:
		menu.visible = true
		return

	if _nivel_instanciado and _nivel_instanciado.has_method("show_victory_menu"):
		_nivel_instanciado.show_victory_menu()
		return

	push_warning("No encontré victory menu (grupo 'victory_menu' o método show_victory_menu).")
