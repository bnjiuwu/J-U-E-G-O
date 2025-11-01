extends CanvasLayer

@onready var panel: ColorRect = $Panel
@onready var title: Label = $VBox/Title
@onready var retry_btn: Button = $VBox/Buttons/Retry
@onready var main_btn: Button = $VBox/Buttons/MainMenu
@onready var quit_btn: Button = $VBox/Buttons/Quit
@onready var anim: AnimationPlayer = $Fade

var main_menu_scene: String = "res://Assets/Scenes/Menu/menu.tscn"

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

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)

func _on_quit() -> void:
	get_tree().quit()
