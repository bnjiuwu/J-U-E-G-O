# Network.gd
extends Node2D

var ws := WebSocketPeer.new()
var conectado := false
var conectando := false

var ping_timer := 0.0
const PING_INTERVAL := 10.0

var matchId := ""

var player_name := ""
var game_id := ""
var game_key := ""
var my_id := ""
# ====== CONTEXTO DEL RIVAL (para UI in-game) ======
var opponent_id: String = ""
var opponent_name: String = ""
var opponent_game_name: String = ""
var my_game_name: String = ""

func leave_match(reason: String = "user_exit") -> void:
	if matchId != "":
		# 1) Avisar al rival (ruta estándar que ya manejas)
		send_game_payload({"close": true, "reason": reason})

		# 2) Pedir al servidor cerrar la instancia del match
		_enviar({
			"event": "finish-game",
			"data": {"matchId": matchId}
		})

	reset_match_state()
	opponent_name = ""
	opponent_game_name = ""

func set_opponent_context(id: String, name: String, game_name: String = "") -> void:
	opponent_id = id
	opponent_name = name
	opponent_game_name = game_name

func clear_opponent_context() -> void:
	opponent_id = ""
	opponent_name = ""
	opponent_game_name = ""

# ====== NUEVO: MUERTES MULTI ======
var death_count: int = 0
var death_limit: int = 5

signal mensaje_recibido(msg)
signal conectado_servidor()
signal local_defeat(deaths: int)

func iniciar(nombre, gameId, gameKey):
	player_name = str(nombre)
	game_id = str(gameId)
	game_key = str(gameKey)
	_start_connect()

func _process(delta):
	# Si no estamos intentando/conectados, no hacemos nada
	if not conectando and not conectado:
		return

	ws.poll()

	# ✅ transición real a conectado cuando esté OPEN
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		if not conectado:
			conectado = true
			conectando = false
			ping_timer = 0.0
			print("✅ [NETWORK] WebSocket OPEN")
			emit_signal("conectado_servidor")

		# keep-alive
		ping_timer += delta
		if ping_timer >= PING_INTERVAL:
			ping_timer = 0.0
			_enviar({"event": "ping"})
			print("📡 [NETWORK] Ping keep-alive")

		# leer mensajes
		while ws.get_available_packet_count() > 0:
			var msg := ws.get_packet().get_string_from_utf8()
			emit_signal("mensaje_recibido", msg)

		return

	# ✅ si se cerró mientras intentábamos o estábamos conectados
	if ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		print("⚠️ [NETWORK] WebSocket cerrado. Reintentando...")
		conectado = false
		conectando = false
		_reconectar()

func _start_connect():
	# ✅ reset limpio para evitar estados raros
	ws = WebSocketPeer.new()
	conectado = false
	conectando = true

	var safe_name := player_name.strip_edges()
	if safe_name == "":
		safe_name = "player"

	# ✅ MUY IMPORTANTE: encode para espacios y caracteres raros
	var url := "ws://cross-game-ucn.martux.cl:4010/?gameId=%s&playerName=%s" % [
		game_id,
		safe_name.uri_encode()
	]

	print("🌐 [NETWORK] Conectando a:", url)

	var err := ws.connect_to_url(url)
	if err != OK:
		print("❌ [NETWORK] Error conectando. Reintento en 1 segundo…")
		conectando = false
		await get_tree().create_timer(1).timeout
		_start_connect()

func _reconectar():
	await get_tree().create_timer(1).timeout
	_start_connect()

func _enviar(dic: Dictionary):
	# Solo enviar si está OPEN
	if ws == null:
		return
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	ws.send_text(JSON.stringify(dic))

func apagar():
	print("🛑 [NETWORK] Apagando conexión…")

	conectado = false
	conectando = false
	ping_timer = 0.0

	if ws and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.close(1000, "User exit")

	# reset
	ws = WebSocketPeer.new()
# ✅ API pública para enviar payload de partida (ataques, etc.)



func reset_match_state() -> void:
	matchId = ""
	death_count = 0
	clear_opponent_context()

func reset_death_counter() -> void:
	death_count = 0

# ya tienes:
# var matchId := ""
# signal mensaje_recibido(msg)

func send_game_payload(payload: Dictionary) -> void:
	if not conectado:
		print("⚠️ [NETWORK] No conectado, no envío payload.")
		return

	if matchId == "":
		print("⚠️ [NETWORK] matchId vacío, no envío payload:", payload)
		return

	_enviar({
		"event": "send-game-data",
		"data": {
			"matchId": matchId,
			"payload": payload
		}
	})
