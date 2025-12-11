extends CanvasLayer

@onready var panel: ColorRect = $Panel
@onready var title: Label = $VBox/Title
@onready var retry_btn: Button = $VBox/Buttons/Retry
@onready var main_btn: Button = $VBox/Buttons/MainMenu
@onready var quit_btn: Button = $VBox/Buttons/Quit
@onready var anim: AnimationPlayer = $Fade

var main_menu_scene: String = "res://Assets/Scenes/Menu/menu.tscn"

var options_music = preload("res://Assets/AUDIOS/spongebob-hawaiian-cocktail.mp3")

@onready var _mixer := $AudioStreamPlayer
var _multi_context: bool = false


func _ready() -> void:
	visible = false
	# Empezar completamente transparente
	panel.modulate.a = 0.0
	$VBox.modulate.a = 0.0
	retry_btn.pressed.connect(_on_retry)
	main_btn.pressed.connect(_on_main_menu)
	quit_btn.pressed.connect(_on_quit)
	

func _is_multiplayer_now() -> bool:
	return Network != null and str(Network.matchId) != ""

func show_death(message: String = "Has muerto") -> void:
	title.text = message.to_upper()
	visible = true
	anim.process_mode = Node.PROCESS_MODE_ALWAYS
	anim.play("fade_in")
	get_tree().paused = true

	_multi_context = _is_multiplayer_now()

	if _multi_context:
		retry_btn.visible = false
		retry_btn.disabled = true
		main_btn.grab_focus()
	else:
		retry_btn.visible = true
		retry_btn.disabled = false
		retry_btn.grab_focus()

	_play_menu_music()
	GlobalsSignals.background_music_pause_requested.emit()

func _notify_close_if_needed() -> void:
	if not _is_multiplayer_now():
		return

	# 1) Avisar cierre de partida al rival/servidor
	if Network and Network.has_method("send_game_payload"):
		Network.send_game_payload({
			"close": true,
			"reason": "leave_from_death_menu"
		})

	# 2) Limpiar estado local de match
	if Network and Network.has_method("reset_match_state"):
		Network.reset_match_state()

	# 3) Cerrar WebSocket para evitar "jugadores fantasma"
	#    y detener el ping keep-alive en el menú principal
	if Network and Network.has_method("apagar"):
		Network.apagar()



func _on_retry() -> void:
	if _multi_context:
		return
	get_tree().paused = false
	GlobalsSignals.background_music_resume_requested.emit()
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	_notify_close_if_needed()
	get_tree().paused = false
	GlobalsSignals.background_music_resume_requested.emit()
	get_tree().change_scene_to_file(main_menu_scene)

func _on_quit() -> void:
	_notify_close_if_needed()
	get_tree().paused = false
	GlobalsSignals.background_music_resume_requested.emit()
	get_tree().quit()


func _play_menu_music() -> void:
	if not _mixer:
		return
	if _mixer.stream != options_music:
		_mixer.stream = options_music
	if not _mixer.playing:
		_mixer.play()

func _stop_menu_music() -> void:
	if _mixer and _mixer.playing:
		_mixer.stop()
