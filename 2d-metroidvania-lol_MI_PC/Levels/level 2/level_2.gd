extends Node2D

@export var golem_path: NodePath = NodePath("Golem")
@export var next_level_path: String = "res://Levels/level 3/level_3.tscn"
@export var level_complete_delay: float = 2.0
@export var victory_label_path: NodePath = NodePath("VictoryCanvas/VictoryLabel")
@export var victory_text: String = "¡Felicidades!"
@export var fallback_pause_menu_scene: PackedScene = preload("res://Assets/Scenes/Menu/PauseMenu/PauseMenu.tscn")

var _level_complete_triggered: bool = false
var _victory_label: Label
var _fallback_pause_menu: Node = null

func _ready() -> void:
	var golem := get_node_or_null(golem_path)
	if golem and golem.has_signal("boss_died"):
		golem.boss_died.connect(_on_golem_died)
	else:
		push_warning("No se encontró el Golem para conectar boss_died")
	_victory_label = get_node_or_null(victory_label_path)
	if _victory_label:
		_victory_label.visible = false

	var touch_controls := get_node_or_null("Controles/touch_controls")
	if touch_controls and touch_controls.has_signal("pause_pressed"):
		if not touch_controls.pause_pressed.is_connected(_on_pause_button_pressed):
			touch_controls.pause_pressed.connect(_on_pause_button_pressed)

	_ensure_pause_menu_available()

func _on_golem_died(_boss_name: String = "") -> void:
	if _level_complete_triggered:
		return
	_level_complete_triggered = true
	_show_victory_message()
	await _run_level_complete_flow()

func _run_level_complete_flow() -> void:
	if level_complete_delay > 0.0:
		await get_tree().create_timer(level_complete_delay).timeout
	_go_to_next_level()

func _go_to_next_level() -> void:
	var manager := _find_level_manager()
	if manager and manager.has_method("request_next_level"):
		manager.request_next_level()
		return
	if next_level_path.is_empty():
		push_warning("next_level_path vacío, no se puede avanzar al siguiente nivel")
		return
	get_tree().change_scene_to_file(next_level_path)

func _find_level_manager() -> Node:
	var tree := get_tree()
	if tree:
		var mgr := tree.get_first_node_in_group("level_manager")
		if mgr:
			return mgr
	var parent := get_parent()
	while parent:
		if parent.is_in_group("level_manager") or parent.has_method("request_next_level"):
			return parent
		parent = parent.get_parent()
	return null

func _ensure_pause_menu_available() -> void:
	if _find_level_manager():
		return
	var existing := get_tree().get_first_node_in_group("pause_menu")
	if existing:
		return
	if fallback_pause_menu_scene == null:
		push_warning("No hay escena de PauseMenu asignada para el fallback")
		return
	_fallback_pause_menu = fallback_pause_menu_scene.instantiate()
	if _fallback_pause_menu == null:
		push_warning("No se pudo instanciar PauseMenu de respaldo")
		return
	add_child(_fallback_pause_menu)
	if not _fallback_pause_menu.is_in_group("pause_menu"):
		_fallback_pause_menu.add_to_group("pause_menu")

func _show_victory_message() -> void:
	if _victory_label == null:
		return
	_victory_label.text = victory_text
	_victory_label.visible = true

func _on_pause_button_pressed() -> void:
	var manager := _find_level_manager()
	if manager and manager.has_method("toggle_pause"):
		manager.toggle_pause()
		return
	var pause_menu := get_tree().get_first_node_in_group("pause_menu")
	if pause_menu and pause_menu.has_method("toggle_pause"):
		pause_menu.toggle_pause()
		return
	push_warning("No se encontró PauseMenu para pausar")
