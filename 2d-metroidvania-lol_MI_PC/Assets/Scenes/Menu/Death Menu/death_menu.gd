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

func _ready() -> void:
	visible = false
	# Empezar completamente transparente
	panel.modulate.a = 0.0
	$VBox.modulate.a = 0.0
	retry_btn.pressed.connect(_on_retry)
	main_btn.pressed.connect(_on_main_menu)
	quit_btn.pressed.connect(_on_quit)
	

func show_death(message: String = "Has muerto") -> void:
	title.text = message.to_upper()
	visible = true
	anim.process_mode = Node.PROCESS_MODE_ALWAYS
	anim.play("fade_in")
	get_tree().paused = true
	retry_btn.grab_focus()
	_play_menu_music()
	GlobalsSignals.background_music_pause_requested.emit()

func _on_retry() -> void:
	get_tree().paused = false
	GlobalsSignals.background_music_resume_requested.emit()
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	get_tree().paused = false
	GlobalsSignals.background_music_resume_requested.emit()
	get_tree().change_scene_to_file(main_menu_scene)

func _on_quit() -> void:
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
