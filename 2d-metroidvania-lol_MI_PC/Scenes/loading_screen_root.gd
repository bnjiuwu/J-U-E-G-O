extends Control

@onready var loading_panel: Control = $LoadingScreen
var _has_started: bool = false

func _ready() -> void:
	if loading_panel:
		loading_panel.visible = true
		_loading_set_progress(0.0)
	call_deferred("_begin_loading")

func _begin_loading() -> void:
	if _has_started:
		return
	_has_started = true
	var target := SceneLoader.target_scene_path if SceneLoader else ""
	if target.is_empty():
		push_error("SceneLoader: target_scene_path vacío")
		return
	await get_tree().process_frame
	_loading_set_progress(0.5)
	await get_tree().process_frame
	_loading_set_progress(1.0)
	get_tree().change_scene_to_file(target)

func _loading_set_progress(value: float) -> void:
	if not loading_panel:
		return
	if loading_panel.has_method("set_progress"):
		loading_panel.call("set_progress", value)
