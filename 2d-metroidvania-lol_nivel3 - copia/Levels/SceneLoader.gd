# res://Scripts/SceneLoader.gd
extends Node

var target_scene_path: String = ""
const LOADING_SCENE_PATH := "res://Scenes/LoadingScreen.tscn"

func goto_scene(path: String) -> void:
	target_scene_path = path
	get_tree().change_scene_to_file(LOADING_SCENE_PATH)
