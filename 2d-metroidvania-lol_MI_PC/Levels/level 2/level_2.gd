extends Node2D

@export var golem_path: NodePath = NodePath("Golem")
@export var next_level_path: String = "res://Levels/level 3/level_3.tscn"
@export var level_complete_delay: float = 2.0
@export var victory_label_path: NodePath = NodePath("VictoryCanvas/VictoryLabel")
@export var victory_text: String = "¡Felicidades!"

var _level_complete_triggered: bool = false
var _victory_label: Label

func _ready() -> void:
	var golem := get_node_or_null(golem_path)
	if golem and golem.has_signal("boss_died"):
		golem.boss_died.connect(_on_golem_died)
	else:
		push_warning("No se encontró el Golem para conectar boss_died")
	_victory_label = get_node_or_null(victory_label_path)
	if _victory_label:
		_victory_label.visible = false

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

func _show_victory_message() -> void:
	if _victory_label == null:
		return
	_victory_label.text = victory_text
	_victory_label.visible = true
