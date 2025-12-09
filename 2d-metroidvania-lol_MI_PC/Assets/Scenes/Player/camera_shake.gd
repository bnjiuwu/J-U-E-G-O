extends Camera2D

@export var shake_falloff: float = 1.0

var _default_zoom: Vector2

var _base_offset: Vector2
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
var _rng := RandomNumberGenerator.new()
var _zoom_tween: Tween

func _ready() -> void:
	_rng.randomize()
	_base_offset = offset
	_default_zoom = zoom
	add_to_group("camera_shake")

func start_shake(intensity: float = 6.0, duration: float = 0.25) -> void:
	_shake_intensity = max(_shake_intensity, intensity)
	_shake_duration = max(0.001, max(_shake_duration, duration))
	_shake_time = _shake_duration

func transition_zoom(target_zoom: Vector2, duration: float = 0.65) -> void:
	_start_zoom_tween(target_zoom, duration)

func restore_default_zoom(duration: float = 0.65) -> void:
	_start_zoom_tween(_default_zoom, duration)

func set_default_zoom(value: Vector2) -> void:
	_default_zoom = value

func _start_zoom_tween(target_zoom: Vector2, duration: float) -> void:
	duration = max(duration, 0.01)
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_SINE)
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(self, "zoom", target_zoom, duration)

func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time = max(0.0, _shake_time - delta * shake_falloff)
	var damping := _shake_time / _shake_duration
	var random_offset := Vector2(
		_rng.randf_range(-1.0, 1.0),
		_rng.randf_range(-1.0, 1.0)
	) * _shake_intensity * damping
	offset = _base_offset + random_offset
	if _shake_time <= 0.0:
		offset = _base_offset
		_shake_intensity = 0.0
