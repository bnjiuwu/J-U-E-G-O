extends Control

var multi_music = preload("res://Assets/AUDIOS/elevator-bossa-nova_1.mp3")
@onready var _mixer := $AudioStreamPlayer

# === NODOS UI ===
@onready var label: Label = $Panel/Label
@onready var lista: VBoxContainer = $Panel/ScrollContainer/VBoxContainer
@onready var scroll: ScrollContainer = $Panel/ScrollContainer
@onready var btn_enviar: Button = $Panel/Enviar
@onready var btn_ver: Button = $Panel/Ver
@onready var volver: Button = $Volver
@onready var lobby: Panel = $Panel/Lobby

# ✅ Panel2 (nuevo)
@onready var panel_nombre: Control = $Panel2
@onready var name_input: LineEdit = $Panel2/NameInput
@onready var btn_conectar: Button = $Panel2/BtnConectar

@export var default_player_name := "default_name"

# === CONFIGURACIÓN DEL JUEGO ===
# const MY_PLAYER_NAME := "pc_el_uwu"      # ❌ ya no se usa fijo
const MY_GAME_ID := "E"
const MY_GAME_KEY := "FIBE9DV0C3"
const MY_GAME_NAME := "Roberto Mondongo y su pistolita"

# === VARIABLES ===
var conectado := false
var jugadores: Dictionary = {}
var invitaciones: Array = []
var posicion_menu := 0
var modo := 0
var match_id: String = ""
var match_status: String = "WAITING_PLAYERS"
var jugadores_del_match: Array = []
var invitador_id := ""


# ===============================
# ========== HELPERS ============
# ===============================
func _my_name() -> String:
	var n := ""
	if Network:
		n = str(Network.player_name)
	if n.strip_edges() == "":
		n = default_player_name
	return n


# === READY ===
func _ready():
	label.text = "Modo Multijugador"
	lobby.visible = false
	_limpiar_todo()

	scroll.visible = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	btn_enviar.pressed.connect(_on_enviar_pressed)
	btn_ver.pressed.connect(_on_ver_pressed)
	volver.pressed.connect(_on_volver_pressed)

	# ✅ Panel nombre visible
	panel_nombre.visible = true
	name_input.text = default_player_name
	btn_conectar.pressed.connect(_on_conectar_pressed)

	# ✅ bloquear botones hasta conectar
	btn_enviar.disabled = true
	btn_ver.disabled = true

	_play_menu_music()
#===== PROCESS ========= 
func _process(_delta):
	if not conectado:
		return

	Network.ws.poll()
	while Network.ws.get_available_packet_count() > 0:
		var msg := Network.ws.get_packet().get_string_from_utf8()
		_on_mensaje_recibido(msg)


func _on_conectar_pressed():
	var nombre := name_input.text.strip_edges()
	if nombre == "":
		nombre = default_player_name

	# conectar señal UNA vez
	if not Network.mensaje_recibido.is_connected(_on_mensaje_recibido):
		Network.mensaje_recibido.connect(_on_mensaje_recibido)

	Network.iniciar(nombre, MY_GAME_ID, MY_GAME_KEY)
	conectado = true

	# UI
	btn_conectar.disabled = true
	name_input.editable = false
	btn_enviar.disabled = false
	btn_ver.disabled = false
	panel_nombre.visible = false

	print("🧑 Nombre usado:", nombre)

func _play_menu_music() -> void:
	if not _mixer:
		return
	if _mixer.stream != multi_music:
		_mixer.stream = multi_music
	if not _mixer.playing:
		_mixer.play()


func _stop_menu_music() -> void:
	if _mixer and _mixer.playing:
		_mixer.stop()


# === CONEXIÓN (helper post-lobby, etc.) ===
func _conectar_servidor():
	var nombre := _my_name()

	if not Network.mensaje_recibido.is_connected(_on_mensaje_recibido):
		Network.mensaje_recibido.connect(_on_mensaje_recibido)

	Network.iniciar(nombre, MY_GAME_ID, MY_GAME_KEY)
	conectado = true


# === ENVÍO RAW ===
func _enviar(dic: Dictionary):
	if Network.ws == null:
		print("⚠️ [MULTI] Network.ws es null, no envío:", dic)
		return

	if Network.ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("⚠️ [MULTI] WebSocket no está abierto, no envío:", dic)
		return

	Network.ws.send_text(JSON.stringify(dic))


# === UI FACTORY ===
func _crear_panel_estilo(color: Color = Color(0.94, 0.94, 0.94)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.2, 0.2, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(25)
	return style


func _crear_label(texto: String, size := 22) -> Label:
	var lbl := Label.new()
	lbl.text = texto
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


func _crear_boton(texto, size := 18, ancho := 140, alto := 45, accion = null) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(ancho, alto)
	btn.add_theme_font_size_override("font_size", size)
	if accion != null:
		btn.pressed.connect(accion)
	return btn


# === LIMPIAR ESTADO GLOBAL ===
func _limpiar_todo():
	jugadores.clear()
	invitaciones.clear()
	scroll.visible = false
	btn_enviar.visible = true
	btn_ver.visible = true
	posicion_menu = 0
	modo = 0
	match_id = ""
	match_status = "WAITING_PLAYERS"
	for c in lista.get_children():
		c.queue_free()


# ===============================
# ====== MANEJAR MENSAJES =======
# ===============================
func _on_mensaje_recibido(msg: String):
	var data = JSON.parse_string(msg)
	if typeof(data) != TYPE_DICTIONARY or not data.has("event"):
		return

	var evento := str(data["event"])
	print("📡 DEBUG SERVER EVENT:", data)
	print("📩 Evento:", evento)

	match evento:

		# === CONEXIÓN / LOGIN ===
		"connected-to-server":
			print("✅ Conectado. Enviando login…")

			if data.has("data") and typeof(data["data"]) == TYPE_DICTIONARY:
				var d: Dictionary = data.get("data", {})
				if d.has("playerId"):
					Network.my_id = str(d["playerId"])
				elif d.has("id"):
					Network.my_id = str(d["id"])
				print("🆔 Mi ID asignado por el servidor:", Network.my_id)

			_enviar({"event": "login", "data": {"gameKey": MY_GAME_KEY}})


		"login":
			if data.get("status") == "OK":
				print("🧠 Login OK como:", _my_name())
				_enviar({"event": "online-players"})
			else:
				print("❌ Error de login:", data.get("msg", ""))


		# === LISTA DE JUGADORES ===
		"online-players":
			if data.get("status") == "OK":
				_actualizar_jugadores(data.get("data", []))

		"player-connected":
			_registrar_jugador(data.get("data", {}))

		"player-disconnected":
			_borrar_jugador(data.get("data", {}))

		"player-status-changed":
			_actualizar_estado(data.get("data", {}))


		# === MATCHMAKING ===
		"match-request-received":
			_recibir_invitacion(data)

		"send-match-request":
			if data.get("status") == "OK":
				match_id = data.get("data", {}).get("matchId", "")
				print("📨 Invitación enviada. Match ID:", match_id)
			else:
				print("❌ Error en send-match-request:", data.get("msg", ""))

		"accept-match":
			if data.get("status") == "OK":
				match_id = data["data"].get("matchId", "")
				print("🤝 Invitación aceptada. Match ID:", match_id)

				var my_name := _my_name()

				var rival_id = str(data["data"].get("playerId", ""))
				var rival_name = str(data["data"].get("playerName", ""))

				if rival_name == "" and rival_id != "":
					var jugador_info = jugadores.get(rival_id, {})
					rival_name = jugador_info.get("name", "")
					if rival_name == "":
						print("⚠️ Error: El servidor no envió playerName ni se pudo encontrar por ID.")

				if rival_name != "":
					jugadores_del_match = [my_name, rival_name]
				else:
					print("⚠️ Error: No se pudo determinar el nombre del rival.")

				print("👥 Jugadores del match (ACEPT):", jugadores_del_match)

				_enviar({"event": "online-players"})
				await get_tree().create_timer(0.2).timeout

				_enviar({"event": "connect-match", "data": {"matchId": match_id}})
			else:
				print("❌ Error en accept-match:", data.get("msg", ""))


		"match-accepted":
			match_id = data["data"].get("matchId", "")
			print("🎮 El otro jugador aceptó la invitación. Match ID:", match_id)

			jugadores_del_match.clear()

			var my_name := _my_name()

			var rival_id = str(data["data"].get("playerId", ""))
			var rival_name = str(data["data"].get("playerName", ""))

			if rival_name == "" and rival_id != "":
				var jugador_info = jugadores.get(rival_id, {})
				rival_name = jugador_info.get("name", "")
				if rival_name == "":
					print("⚠️ Error: El servidor no envió playerName ni se pudo encontrar por ID.")

			if rival_name != "":
				jugadores_del_match = [my_name, rival_name]
			else:
				print("⚠️ Error: No se pudo determinar el nombre del rival.")

			print("👥 Jugadores del match (ACCEPTED):", jugadores_del_match)

			_enviar({"event": "online-players"})
			await get_tree().create_timer(0.2).timeout

			_enviar({"event": "connect-match", "data": {"matchId": match_id}})


		"connect-match":
			if data.get("status") == "OK":
				match_id = data["data"].get("matchId", "")
				match_status = "CONNECTED"

				if match_id != "":
					Network.matchId = match_id

				print("🔗 Match conectado:", match_id)
				print("👥 Jugadores del match:", jugadores_del_match)

				_actualizar_lista()


		# === READY / LOBBY ===
		"players-ready":
			print("🟢 Ambos jugadores se conectaron al match. Abriendo lobby…")
			match_status = "READY"
			_abrir_lobby()


		"ping-match":
			var raw = data.get("data", {})
			var jugador_id = raw.get("playerId", "")

			print("📶 ping-match recibido del ID:", jugador_id)

			if jugador_id == Network.my_id:
				print("🟢 YO estoy listo")
				_marcar_local_listo()
				return

			var rival_name = ""
			for id in jugadores.keys():
				if id == jugador_id:
					rival_name = jugadores[id].get("name", "")
					break

			print("🟦 Rival listo:", rival_name)
			_marcar_rival_listo()


		"match-start":
			print("🚀 match-start recibido")

			if match_id == "":
				match_id = str(data.get("data", {}).get("matchId", ""))

			Network.matchId = match_id
			print("✅ Network.matchId seteado:", Network.matchId)

			_stop_menu_music()

			await get_tree().process_frame
			get_tree().change_scene_to_file("res://Levels/LEVEL MANAGER/level_manager.tscn")


		# === CIERRE REMOTO (OTRO JUGADOR) ===
		"close-match":
			var raw = data.get("data", {})
			var rival_name := str(raw.get("playerName", ""))

			print("🚪 close-match recibido — playerName:", rival_name)

			if rival_name == "" and raw.has("playerId"):
				var pid := str(raw.get("playerId", ""))
				if jugadores.has(pid):
					rival_name = str(jugadores[pid].get("name", ""))

			if rival_name == "":
				print("⚠️ close-match sin nombre reconocido → cierro por seguridad.")
				_finalizar_partida_por_rival()
				return

			if rival_name == _my_name():
				print("➡️ close-match indica que YO abandoné (eco del server).")
				return

			_eliminar_rival_de_lobby_por_nombre(rival_name)
			return


		"quit-match":
			print("📥 quit-match recibido (ACK de que yo abandoné el lobby)")
			return


		"game-ended":
			print("🏁 game-ended recibido — partida terminó.")
			await _finalizar_partida_por_rival()


		"send-game-data":
			print("📨 Servidor ACK → send-game-data OK.")


		"receive-game-data":
			var payload = data.get("data", {}).get("payload", {})

			if payload.has("close") and payload["close"] == true:
				print("🚪 rival envió close — cerrando partida por remoto.")
				await _finalizar_partida_por_rival()

			if payload.has("type") and payload["type"] == "attack":
				var dmg = payload.get("damage", 5)
				print("🔥 ATAQUE RECIBIDO → daño:", dmg)

				var nivel = get_tree().current_scene
				if nivel.has_method("recibir_ataque"):
					nivel.recibir_ataque(dmg)


		"finish-game":
			print("📤 Respuesta a finish-game:", data)


		"rematch-request":
			print("🔄 Rematch solicitado por el otro jugador.")


		_:
			print("ℹ️ Evento no manejado:", evento)



# ===============================
# ====== SALIDA DEL RIVAL =======
# ===============================
func _finalizar_partida_por_rival():
	print("🧹 Rival abandonó — cerrando lobby/partida")

	match_id = ""
	match_status = "WAITING_PLAYERS"

	if lobby.visible:
		lobby.visible = false
		var box := $Panel/Lobby/VBoxContainer
		for c in box.get_children():
			c.queue_free()

	scroll.visible = false
	btn_enviar.visible = true
	btn_ver.visible = true
	posicion_menu = 0
	label.text = "Modo Multijugador"



# ===============================
# ============ LOBBY ============
# ===============================
func _abrir_lobby():
	print("🪩 Mostrando lobby...")

	lobby.visible = true

	var box: VBoxContainer = $Panel/Lobby/VBoxContainer
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 25)

	for c in box.get_children():
		c.queue_free()

	var titulo := _crear_label("🏁 LOBBY DE PARTIDA", 28)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(titulo)

	var my_name := _my_name()

	var lista_final: Array = []

	lista_final.append({
		"name": my_name,
		"game_name": MY_GAME_NAME,
		"local": true
	})

	for pid in jugadores.keys():
		var j = jugadores[pid]
		var rival_name = j.get("name", "")

		if jugadores_del_match.has(rival_name) and rival_name != my_name:
			lista_final.append({
				"name": rival_name,
				"game_name": j.get("game_name", "Yggdrasil: Last Stand"),
				"local": false
			})
			break

	print("📌 Jugadores en el lobby del match:", lista_final)

	for jugador in lista_final:
		var jugador_nombre = jugador["name"]
		var game_name = jugador["game_name"]

		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_theme_constant_override("separation", 40)

		var texto = "👤 " + str(jugador_nombre) + "  | 🎮 " + str(game_name)
		var lbl := _crear_label(texto, 24)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fila.add_child(lbl)

		var btn_estado := _crear_boton("❌ No listo", 18, 160, 45)
		btn_estado.name = jugador_nombre
		btn_estado.toggle_mode = true

		if jugador["local"] == true:
			btn_estado.disabled = false

			btn_estado.pressed.connect(func():
				btn_estado.text = "⏳ Esperando confirmación..."
				print("🟢 Enviando ping-match...")

				_enviar({
					"event": "ping-match",
					"data": { "matchId": match_id }
				})

				print("📡 Enviado ping-match (estoy listo)")
			)
		else:
			btn_estado.disabled = true

		# ✅ FIX: el botón va dentro de la fila
		box.add_child(fila)
		box.add_child(btn_estado)

	print("🎯 Lobby cargado con", lista_final.size(), "jugadores.")


func _eliminar_rival_de_lobby_por_nombre(rival_name: String):
	print("🗑️ Eliminando del lobby al rival:", rival_name)

	var box: VBoxContainer = $Panel/Lobby/VBoxContainer

	for fila in box.get_children():
		for sub in fila.get_children():
			if sub is Label and sub.text.contains(rival_name):
				print("✔️ Fila encontrada y eliminada:", rival_name)
				fila.queue_free()
				break

	for fila in box.get_children():
		for sub in fila.get_children():
			if sub is Button:
				sub.disabled = true
				sub.text = "⏳ Rival desconectado"

	label.text = "El rival abandonó la sala"


func _actualizar_ready_ui_de(jugador_ready: String, listo: bool):
	var box: VBoxContainer = $Panel/Lobby/VBoxContainer
	for c in box.get_children():
		for sub in c.get_children():
			if sub is Button and sub.name.to_lower() == jugador_ready.to_lower():
				sub.text = "✅ Listo" if listo else "❌ No listo"
				return



# ===============================
# ====== GESTIÓN JUGADORES ======
# ===============================
func _registrar_jugador(info: Dictionary):
	if info.has("id"):
		jugadores[info["id"]] = {
			"name": info.get("name", "Desconocido"),
			"status": info.get("status", "UNKNOWN")
		}
	_actualizar_lista()


func _borrar_jugador(info: Dictionary):
	if info.has("id"):
		jugadores.erase(info["id"])
	_actualizar_lista()


func _actualizar_estado(info: Dictionary):
	var pid = info.get("playerId")
	if pid and jugadores.has(pid):
		jugadores[pid]["status"] = info.get("playerStatus", "UNKNOWN")
		if info.has("game"):
			var g = info.get("game")
			if typeof(g) == TYPE_DICTIONARY:
				jugadores[pid]["game_name"] = g.get("name", jugadores[pid].get("game_name", "Juego?"))

	_actualizar_lista()


func _actualizar_jugadores(lista_servidor: Array):
	jugadores.clear()

	var mi_nombre_lower = _my_name().to_lower()

	for j in lista_servidor:
		var jugador_nombre_server = str(j.get("name", ""))
		var jugador_nombre_lower = jugador_nombre_server.to_lower()

		if jugador_nombre_lower == mi_nombre_lower:
			continue

		var id := str(j.get("id", ""))
		if id == "":
			continue

		var game_name := "Juego NO REPORTADO"
		var match_id_jugador := ""
		if j.has("game"):
			var g = j.get("game")
			if typeof(g) == TYPE_DICTIONARY:
				game_name = str(g.get("name", "Juego NO REPORTADO"))
				match_id_jugador = str(g.get("matchId", ""))

		jugadores[id] = {
			"name": jugador_nombre_server,
			"status": j.get("status", "UNKNOWN"),
			"game_name": game_name,
			"match_id": match_id_jugador
		}

	print("📌 Jugadores actualizados:", jugadores)
	_actualizar_lista()



# ===============================
# ======== BOTONES UI ===========
# ===============================
func _on_enviar_pressed():
	scroll.visible = true
	btn_enviar.visible = false
	btn_ver.visible = false
	posicion_menu = 1
	label.text = "Jugadores conectados"
	_enviar({"event": "online-players"})


func _on_ver_pressed():
	scroll.visible = true
	btn_enviar.visible = false
	btn_ver.visible = false
	posicion_menu = 1
	modo = 2
	label.text = "Invitaciones recibidas"
	_actualizar_lista_invitaciones()


func _actualizar_lista():
	for c in lista.get_children():
		c.queue_free()

	if jugadores.is_empty():
		lista.add_child(_crear_label("❌ No hay jugadores conectados", 22))
		return

	for id in jugadores.keys():
		var j = jugadores[id]

		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(600, 110)
		panel.add_theme_stylebox_override("panel", _crear_panel_estilo())

		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 60)

		var lbl := _crear_label(j["name"], 22)
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.add_child(lbl)
		fila.add_child(center)

		var estado = j.get("status", "AVAILABLE")
		var btn: Button
		if estado == "BUSY" or estado == "IN_MATCH":
			btn = _crear_boton("🕹️ Ocupado", 20)
			btn.disabled = true
		else:
			btn = _crear_boton("📨 Invitar", 20, 180, 49, func(): _enviar_invitacion(j))
		fila.add_child(btn)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		margin.add_theme_constant_override("margin_left", 24)
		margin.add_theme_constant_override("margin_right", 24)
		margin.add_child(fila)

		panel.add_child(margin)
		lista.add_child(panel)



# ===============================
# ========= INVITACIONES ========
# ===============================
func _recibir_invitacion(data: Dictionary):
	var info = data.get("data", {})
	var pid = info.get("playerId", "")
	var mid = info.get("matchId", "")
	var nombre = jugadores.get(pid, {}).get("name", "Desconocido")
	invitador_id = pid
	invitaciones.append({"playerId": pid, "matchId": mid, "name": nombre})
	_actualizar_lista_invitaciones()


func _enviar_invitacion(jugador: Dictionary):
	for pid in jugadores.keys():
		if jugadores[pid] == jugador:
			print("⚔️ Enviando invitación a:", jugador["name"])
			_enviar({"event": "send-match-request", "data": {"playerId": pid}})
			return


func _aceptar_invitacion(info: Dictionary):
	print("✅ Aceptando invitación...")

	var mid = info.get("matchId", "")

	_enviar({"event": "accept-match"})

	invitaciones = invitaciones.filter(func(i):
		return i.get("matchId", "") != mid
	)

	_actualizar_lista_invitaciones()

	var my_name := _my_name()

	if invitador_id != "":
		var jugador_info = jugadores.get(invitador_id, {})
		var rival_name = jugador_info.get("name", "")

		if rival_name != "":
			jugadores_del_match = [my_name, rival_name]
			print("👥 Jugadores del match (ACEPTACIÓN LOCAL):", jugadores_del_match)
		else:
			print("⚠️ Rival ID encontrado pero nombre vacío. ID:", invitador_id)


func _rechazar_invitacion(info: Dictionary):
	_enviar({"event": "reject-match"})

	var mid = info.get("matchId", "")
	invitaciones = invitaciones.filter(func(i):
		return i.get("matchId", "") != mid
	)

	_actualizar_lista_invitaciones()


func _actualizar_lista_invitaciones():
	for c in lista.get_children():
		c.queue_free()

	if invitaciones.is_empty():
		lista.add_child(_crear_label("No hay invitaciones", 22))
		return

	for info in invitaciones:
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(600, 120)
		panel.add_theme_stylebox_override("panel", _crear_panel_estilo())

		var fila := HBoxContainer.new()
		fila.alignment = BoxContainer.ALIGNMENT_CENTER
		fila.add_theme_constant_override("separation", 40)
		fila.add_child(_crear_label(info["name"], 24))
		fila.add_child(_crear_boton("✅ Aceptar", 18, 140, 45, func(): _aceptar_invitacion(info)))
		fila.add_child(_crear_boton("❌ Rechazar", 18, 140, 45, func(): _rechazar_invitacion(info)))

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_child(fila)

		panel.add_child(margin)
		lista.add_child(panel)



# ===============================
# ============ VOLVER ===========
# ===============================
func _on_volver_pressed():

	if lobby.visible:
		print("🚪 Saliendo del lobby manualmente…")

		if match_id != "":
			print("📤 quit-match enviado (abandono del lobby)")
			_enviar({
				"event": "quit-match",
				"data": {"matchId": match_id}
			})
			await get_tree().create_timer(0.25).timeout

		match_id = ""
		match_status = "WAITING_PLAYERS"

		lobby.visible = false
		print("🔌 Reiniciando conexión...")

		if Network.ws:
			Network.apagar()
			conectado = false

		await get_tree().create_timer(0.4).timeout

		print("🌐 Re-conectando para quedar AVAILABLE…")
		_conectar_servidor()

		await get_tree().create_timer(0.5).timeout

		if conectado:
			_enviar({"event": "online-players"})

		var box := $Panel/Lobby/VBoxContainer
		for c in box.get_children():
			c.queue_free()

		scroll.visible = false
		btn_enviar.visible = true
		btn_ver.visible = true
		label.text = "Modo Multijugador"
		posicion_menu = 0

		return


	if posicion_menu == 0:
		if Network.ws:
			print("🔌 Cerrando WebSocket al salir del modo multijugador…")
			Network.apagar()
			conectado = false

		_limpiar_todo()
		get_tree().change_scene_to_file("res://Assets/Scenes/Menu/menu.tscn")
	else:
		scroll.visible = false
		btn_enviar.visible = true
		btn_ver.visible = true
		posicion_menu = 0
		label.text = "Modo Multijugador"



# ===============================
# ====== READY UI SIMPLE ========
# ===============================
func _marcar_rival_listo():
	var box = $Panel/Lobby/VBoxContainer
	if box.get_child_count() >= 3:
		var fila_rival = box.get_child(2)
		for sub in fila_rival.get_children():
			if sub is Button:
				sub.text = "🏁 Confirmado"


func _marcar_local_listo():
	var box = $Panel/Lobby/VBoxContainer
	if box.get_child_count() >= 2:
		var fila_local = box.get_child(1)
		for sub in fila_local.get_children():
			if sub is Button:
				sub.text = "✅ Listo"
				sub.disabled = true
