extends Control

#=== jugar ===
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Levels/level 1/level_1.tscn")
	pass # Replace with function body.

#==== options ====
func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://Assets/Scenes/Menu/options.tscn")
	pass # Replace with function body.

#==== Q U I T ======
func _on_quit_pressed() -> void:
	get_tree().quit()
	pass # Replace with function body.
