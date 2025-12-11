extends Node

@export var music_stream: AudioStream
@export var play_on_ready: bool = true
@export var loop: bool = true
@export var volume_db: float = -6.0
@export var bus_name: StringName = &"Music"

var _player: AudioStreamPlayer
var _pause_depth: int = 0

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_player.bus = bus_name if bus_name != StringName() else &"Music"
	_player.autoplay = false
	add_child(_player)
	_player.finished.connect(_on_music_finished)
	GlobalsSignals.background_music_pause_requested.connect(_on_pause_requested)
	GlobalsSignals.background_music_resume_requested.connect(_on_resume_requested)
	_apply_settings()
	if play_on_ready:
		play()

func play() -> void:
	if _player == null or music_stream == null:
		return
	_player.stop()
	_player.stream = music_stream
	_player.volume_db = volume_db
	if _pause_depth <= 0:
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

func _on_pause_requested() -> void:
	_pause_depth += 1
	if _player and _player.playing:
		_player.stream_paused = true

func _on_resume_requested() -> void:
	_pause_depth = max(0, _pause_depth - 1)
	if _pause_depth == 0 and _player:
		_player.stream_paused = false
