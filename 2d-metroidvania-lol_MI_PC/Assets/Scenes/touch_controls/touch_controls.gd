extends CanvasLayer

signal pause_pressed

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_GAMEPLAY := "gameplay"

const FORMAL_JUMP_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/Formal Controls/Salto.png")
const FORMAL_FIRE_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/Formal Controls/Disparo.png")
const FORMAL_DASH_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/Formal Controls/Dash.png")
const FORMAL_SKILL_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/Formal Controls/Especial.png")
const FORMAL_PAUSE_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/Formal Controls/Pause formal.png")
const FORMAL_JOYSTICK_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/Formal Controls/Joistyck.png")

const MEME_JUMP_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/saltoBoton.png")
const MEME_FIRE_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/fireBoton.png")
const MEME_DASH_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/dashBoton.png")
const MEME_SKILL_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/SkillButton.png")
const MEME_PAUSE_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/pause boton.png")
const MEME_JOYSTICK_TEXTURE: Texture2D = preload("res://Assets/sprites/objects type shi/palta.png")


@onready var button_pause: TouchScreenButton = $pause_button
@onready var joystick: Node2D = $Joystick
@onready var joystick_knob: Sprite2D = $Joystick/Knob
@onready var fire_button: TouchScreenButton = $Control/FireButton
@onready var dash_button: TouchScreenButton = $Control/DashButton
@onready var jump_button: TouchScreenButton = $Control/JumpButton
@onready var skill_button: TouchScreenButton = $Control/SkillButton

var _default_positions: Dictionary = {}
var _mirrored_positions: Dictionary = {}
var _left_handed: bool = false
var _skin_is_meme: bool = false
var _force_visible_on_desktop: bool = false

func _ready() -> void:
	add_to_group("touch_controls_ui")
	button_pause.pressed.connect(_on_pause_button_pressed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_cache_positions()
	_load_layout_setting()
	_apply_layout(_left_handed)
	_set_initial_skin()
	_set_initial_visibility()

func _on_pause_button_pressed() -> void:
	print("🟡 Pausa tocada")
	emit_signal("pause_pressed")

func set_left_handed(enabled: bool) -> void:
	_left_handed = enabled
	_apply_layout(_left_handed)

func set_skin_mode(use_meme_mode: bool) -> void:
	_skin_is_meme = use_meme_mode
	_apply_button_skins()

func set_force_visible_on_desktop(enabled: bool) -> void:
	_force_visible_on_desktop = enabled
	_apply_visibility()

func _cache_positions() -> void:
	_default_positions = {
		"Joystick": joystick.position,
		"FireButton": fire_button.position,
		"DashButton": dash_button.position,
		"JumpButton": jump_button.position,
		"SkillButton": skill_button.position,
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
	fire_button.position = source.get("FireButton", fire_button.position)
	dash_button.position = source.get("DashButton", dash_button.position)
	jump_button.position = source.get("JumpButton", jump_button.position)
	skill_button.position = source.get("SkillButton", skill_button.position)

func _load_layout_setting() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	_left_handed = cfg.get_value(SECTION_GAMEPLAY, "left_handed", false)

func _on_viewport_size_changed() -> void:
	_cache_mirrored_positions()
	_apply_layout(_left_handed)

func _set_initial_skin() -> void:
	var meme_enabled := GlobalsSignals.get_meme_mode()
	if not GlobalsSignals.meme_mode_changed.is_connected(_on_meme_mode_changed):
		GlobalsSignals.meme_mode_changed.connect(_on_meme_mode_changed)
	set_skin_mode(meme_enabled)

func _set_initial_visibility() -> void:
	var forced_desktop := GlobalsSignals.get_touch_controls_on_desktop()
	if not GlobalsSignals.touch_controls_visibility_changed.is_connected(_on_touch_controls_visibility_changed):
		GlobalsSignals.touch_controls_visibility_changed.connect(_on_touch_controls_visibility_changed)
	set_force_visible_on_desktop(forced_desktop)

func _apply_button_skins() -> void:
	var jump_texture: Texture2D
	var fire_texture: Texture2D
	var dash_texture: Texture2D
	var skill_texture: Texture2D
	var pause_texture: Texture2D
	var joystick_texture: Texture2D
	if _skin_is_meme:
		jump_texture = MEME_JUMP_TEXTURE
		fire_texture = MEME_FIRE_TEXTURE
		dash_texture = MEME_DASH_TEXTURE
		skill_texture = MEME_SKILL_TEXTURE
		pause_texture = MEME_PAUSE_TEXTURE
		joystick_texture = MEME_JOYSTICK_TEXTURE
	else:
		jump_texture = FORMAL_JUMP_TEXTURE
		fire_texture = FORMAL_FIRE_TEXTURE
		dash_texture = FORMAL_DASH_TEXTURE
		skill_texture = FORMAL_SKILL_TEXTURE
		pause_texture = FORMAL_PAUSE_TEXTURE
		joystick_texture = FORMAL_JOYSTICK_TEXTURE
	_set_button_visuals(jump_button, jump_texture)
	_set_button_visuals(fire_button, fire_texture)
	_set_button_visuals(dash_button, dash_texture)
	_set_button_visuals(skill_button, skill_texture)
	button_pause.texture_normal = pause_texture
	button_pause.texture_pressed = pause_texture
	if is_instance_valid(joystick_knob):
		joystick_knob.texture = joystick_texture

func _set_button_visuals(button: TouchScreenButton, texture: Texture2D) -> void:
	button.texture_normal = texture
	button.texture_pressed = texture
	# Scales remain defined in the scene so layout stays consistent across skins.

func _apply_visibility() -> void:
	visible = _force_visible_on_desktop or OS.has_feature("mobile")

func _on_meme_mode_changed(enabled: bool) -> void:
	set_skin_mode(enabled)

func _on_touch_controls_visibility_changed(enabled: bool) -> void:
	set_force_visible_on_desktop(enabled)
