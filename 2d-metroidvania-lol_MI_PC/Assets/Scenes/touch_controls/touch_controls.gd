extends CanvasLayer

signal pause_pressed

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_GAMEPLAY := "gameplay"

@onready var button_pause: TouchScreenButton = $pause_button
@onready var joystick: Node2D = $Joystick
@onready var fire_button: TouchScreenButton = $Control/FIRE
@onready var dash_button: TouchScreenButton = $Control/DASH
@onready var jump_button: TouchScreenButton = $Control/JUMP
@onready var skill_button: TouchScreenButton = $Control/SKILL

var _default_positions: Dictionary = {}
var _mirrored_positions: Dictionary = {}
var _left_handed: bool = false

func _ready() -> void:
	add_to_group("touch_controls_ui")
	button_pause.pressed.connect(_on_pause_button_pressed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_cache_positions()
	_load_layout_setting()
	_apply_layout(_left_handed)

func _on_pause_button_pressed() -> void:
	print("🟡 Pausa tocada")
	emit_signal("pause_pressed")

func set_left_handed(enabled: bool) -> void:
	_left_handed = enabled
	_apply_layout(_left_handed)

func _cache_positions() -> void:
	_default_positions = {
		"Joystick": joystick.position,
		"FIRE": fire_button.position,
		"DASH": dash_button.position,
		"JUMP": jump_button.position,
		"SKILL": skill_button.position,
	}
	_cache_mirrored_positions()

func _cache_mirrored_positions() -> void:
	var viewport_width: float = float(get_viewport().size.x)
	if viewport_width <= 0.0:
		viewport_width = float(ProjectSettings.get_setting("display/window/size/viewport_width", 960))

	_mirrored_positions = {}
	for key in _default_positions.keys():
		var original: Vector2 = _default_positions[key]
		var mirrored_x := viewport_width - original.x
		_mirrored_positions[key] = Vector2(mirrored_x, original.y)

func _apply_layout(use_left_handed: bool) -> void:
	var source := _mirrored_positions if use_left_handed else _default_positions
	if source.is_empty():
		return
	joystick.position = source.get("Joystick", joystick.position)
	fire_button.position = source.get("FIRE", fire_button.position)
	dash_button.position = source.get("DASH", dash_button.position)
	jump_button.position = source.get("JUMP", jump_button.position)
	skill_button.position = source.get("SKILL", skill_button.position)

func _load_layout_setting() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	_left_handed = cfg.get_value(SECTION_GAMEPLAY, "left_handed", false)

func _on_viewport_size_changed() -> void:
	_cache_mirrored_positions()
	_apply_layout(_left_handed)
