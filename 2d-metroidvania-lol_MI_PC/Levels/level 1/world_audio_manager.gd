extends Node

@export var music_stream: AudioStream
@export var play_on_ready: bool = true
@export var loop: bool = true
@export var volume_db: float = -6.0
@export var bus_name: StringName = &"Music"

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = bus_name if bus_name != StringName() else &"Music"
	_player.autoplay = false
	add_child(_player)
	_player.finished.connect(_on_music_finished)
	_apply_settings()
	if play_on_ready:
		play()

func play() -> void:
	if _player == null or music_stream == null:
		return
	_player.stop()
	_player.stream = music_stream
	_player.volume_db = volume_db
	_player.play()

func stop() -> void:
	if _player:
		_player.stop()

func set_music(stream: AudioStream, autoplay: bool = true) -> void:
	music_stream = stream
	_apply_settings()
	if autoplay:
		play()

func _apply_settings() -> void:
	if _player == null:
		return
	_player.volume_db = volume_db
	_player.bus = bus_name if bus_name != StringName() else &"Music"

func _on_music_finished() -> void:
	if loop and music_stream and _player:
		_player.play()
