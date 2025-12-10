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

func _resume():
	get_tree().paused = false
	visible = false

func _on_resume_pressed():
	_resume()

func _on_restart_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Assets/Scenes/Menu/menu.tscn")
	
