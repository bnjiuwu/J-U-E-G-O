extends CanvasLayer


@export var options : PackedScene

@onready var btn_resume = $VBoxContainer/reanudar
@onready var btn_restart = $VBoxContainer/reiniciar
@onready var btn_quit = $VBoxContainer/salir_a_menu

func _ready():
	visible = false  # Oculto al inicio
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
func toggle_pause():
	print("🟣 toggle_pause ejecutado. visible:", visible)
	if visible:
		_resume()
	else:
		_pause()

func _pause():
	get_tree().paused = true
	visible = true
	GlobalsSignals.background_music_pause_requested.emit()

func _resume():
	get_tree().paused = false
	visible = false
	GlobalsSignals.background_music_resume_requested.emit()

func _on_resume_pressed():
	_resume()

func _on_restart_pressed():
	GlobalsSignals.background_music_resume_requested.emit()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	print("🔴 PauseMenu: salir al menú principal")

	# 1) Asegurar que el árbol NO quede pausado
	#    (esto afecta también al menú principal)
	Engine.time_scale = 1.0

	# 2) Si estás en multijugador, avisar derrota + cerrar conexión
	if Network and str(Network.matchId) != "":
		# Notificar derrota al rival
		if Network.has_method("send_game_payload"):
			Network.send_game_payload({
				"type": "defeat",
				"reason": "leave_from_pause_menu"
			})

		# Cerrar match / conexión según tu API de Network
		if Network.has_method("leave_match"):
			Network.leave_match("leave_from_pause_menu")

	# 3) Volver al menú principal
	GlobalsSignals.background_music_resume_requested.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Assets/Scenes/Menu/menu.tscn")
