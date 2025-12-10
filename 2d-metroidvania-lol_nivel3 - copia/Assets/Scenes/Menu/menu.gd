extends Control

const MENU_MUSIC: AudioStream = preload("res://Assets/Scenes/Menu/audio/Las Aventuras de Roberto Mondongo.mp3")

@onready var _music_player: AudioStreamPlayer = $MusicPlayer



func _ready() -> void:
	_play_menu_music()

#=== jugar ===
func _on_play_pressed() -> void:
	_stop_menu_music()
	get_tree().change_scene_to_file("res://Levels/LEVEL MANAGER/level_manager.tscn")

#==== options ====
func _on_options_pressed() -> void:
	_stop_menu_music()
	get_tree().change_scene_to_file("res://Assets/Scenes/Menu/opciones/options.tscn")
	_music_player.play()
#==== Q U I T ======
func _on_quit_pressed() -> void:
	_stop_menu_music()
	get_tree().quit()


func _on_multi_pressed() -> void:
	_stop_menu_music()
	get_tree().change_scene_to_file("res://Multijugador/Escenas/Multijugador.tscn")

func _play_menu_music() -> void:
	if not _music_player:
		return
	if _music_player.stream != MENU_MUSIC:
		_music_player.stream = MENU_MUSIC
	if not _music_player.playing:
		_music_player.play()

func _stop_menu_music() -> void:
	if _music_player and _music_player.playing:
		_music_player.stop()
