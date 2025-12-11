extends CanvasLayer


@export var options : PackedScene

@onready var btn_resume = $VBoxContainer/reanudar
@onready var btn_restart = $VBoxContainer/reiniciar
@onready var btn_quit = $VBoxContainer/salir_a_menu

var _loading_screen_cache: Control = null

func _ready():
	visible = false  # Oculto al inicio
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	_refresh_loading_screen()
	
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
	_resume()
	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm and lm.has_method("request_restart_level"):
		lm.request_restart_level()
		return
	_restart_current_scene_standalone()

func _on_quit_pressed():
	_resume()  # asegura que el árbol no quede pausado
	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm and lm.has_method("exit_to_main_menu_from_pause"):
		lm.exit_to_main_menu_from_pause()
		return

	# Fallback extremo (si por algún motivo no está LevelManager)
	_goto_with_loading("res://Assets/Scenes/Menu/menu.tscn")

func _restart_current_scene_standalone() -> void:
	var current_scene := get_tree().current_scene
	var path := ""
	if current_scene and current_scene.scene_file_path != "":
		path = current_scene.scene_file_path
	if path.is_empty():
		_show_loading_screen_fallback()
		call_deferred("_reload_current_scene_fallback")
	else:
		_goto_with_loading(path)

func _reload_current_scene_fallback() -> void:
	get_tree().reload_current_scene()

func _goto_with_loading(path: String) -> void:
	if SceneLoader:
		SceneLoader.goto_scene(path)
		return
	_show_loading_screen_fallback()
	call_deferred("_change_scene_direct", path)

func _change_scene_direct(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _refresh_loading_screen() -> void:
	if _loading_screen_cache and is_instance_valid(_loading_screen_cache):
		return
	_loading_screen_cache = get_tree().get_first_node_in_group("loading_screen")

func _show_loading_screen_fallback() -> void:
	_refresh_loading_screen()
	if _loading_screen_cache:
		_loading_screen_cache.visible = true
		if _loading_screen_cache.has_method("set_progress"):
			_loading_screen_cache.call("set_progress", 0.0)
	
