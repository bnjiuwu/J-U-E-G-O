extends Control

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const SECTION_GAMEPLAY := "gameplay"
const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

@onready var master_slider: HSlider = $ColorRect/MainMargin/ContentScroll/Content/AudioCard/AudioVBox/MasterRow/MasterSlider
@onready var music_slider: HSlider = $ColorRect/MainMargin/ContentScroll/Content/AudioCard/AudioVBox/MusicRow/MusicSlider
@onready var sfx_slider: HSlider = $ColorRect/MainMargin/ContentScroll/Content/AudioCard/AudioVBox/SfxRow/SfxSlider
@onready var master_label: Label = $ColorRect/MainMargin/ContentScroll/Content/AudioCard/AudioVBox/MasterRow/MasterValue
@onready var music_label: Label = $ColorRect/MainMargin/ContentScroll/Content/AudioCard/AudioVBox/MusicRow/MusicValue
@onready var sfx_label: Label = $ColorRect/MainMargin/ContentScroll/Content/AudioCard/AudioVBox/SfxRow/SfxValue
@onready var music_row: Control = $ColorRect/MainMargin/ContentScroll/Content/AudioCard/AudioVBox/MusicRow
@onready var sfx_row: Control = $ColorRect/MainMargin/ContentScroll/Content/AudioCard/AudioVBox/SfxRow
@onready var vibration_toggle: CheckButton = $ColorRect/MainMargin/ContentScroll/Content/GameplayCard/GameplayVBox/VibrationRow/VibrationToggle
@onready var left_handed_toggle: CheckButton = $ColorRect/MainMargin/ContentScroll/Content/GameplayCard/GameplayVBox/LeftHandRow/LeftHandToggle
@onready var touch_toggle: CheckButton = $ColorRect/MainMargin/ContentScroll/Content/GameplayCard/GameplayVBox/TouchRow/TouchToggle
@onready var meme_mode_toggle: CheckButton = $ColorRect/MainMargin/ContentScroll/Content/GameplayCard/GameplayVBox/SkinModeRow/MemeModeToggle

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var vibration_enabled: bool = true
var left_handed_mode: bool = false
var touch_controls_on_pc: bool = false
var meme_mode_enabled: bool = false

var _updating_ui: bool = false
var _master_bus_available: bool = true
var _music_bus_available: bool = false
var _sfx_bus_available: bool = false

func _ready() -> void:
	_load_settings()
	_apply_audio_volumes()
	_update_audio_labels()
	apply_vibration_preview()
	update_touch_controls_layout()
	update_touch_controls_visibility()
	update_touch_controls_skin()

func _on_master_slider_value_changed(value: float) -> void:
	if _updating_ui:
		return
	master_volume = clamp(value, 0.0, 1.0)
	_set_volume_label(master_label, master_volume, _master_bus_available)
	if _master_bus_available:
		_apply_bus_volume(MASTER_BUS, master_volume)
	_save_settings()

func _on_music_slider_value_changed(value: float) -> void:
	if _updating_ui:
		return
	music_volume = clamp(value, 0.0, 1.0)
	_set_volume_label(music_label, music_volume, _music_bus_available)
	if _music_bus_available:
		_apply_bus_volume(MUSIC_BUS, music_volume)
	_save_settings()

func _on_sfx_slider_value_changed(value: float) -> void:
	if _updating_ui:
		return
	sfx_volume = clamp(value, 0.0, 1.0)
	_set_volume_label(sfx_label, sfx_volume, _sfx_bus_available)
	if _sfx_bus_available:
		_apply_bus_volume(SFX_BUS, sfx_volume)
	_save_settings()

func _on_vibration_toggle_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	vibration_enabled = pressed
	apply_vibration_preview()
	_save_settings()

func _on_left_handed_toggle_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	left_handed_mode = pressed
	update_touch_controls_layout()
	_save_settings()

func _on_touch_toggle_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	touch_controls_on_pc = pressed
	update_touch_controls_visibility()
	_save_settings()

func _on_meme_mode_toggle_toggled(pressed: bool) -> void:
	if _updating_ui:
		return
	meme_mode_enabled = pressed
	GlobalsSignals.set_meme_mode(meme_mode_enabled, false)
	update_touch_controls_skin()
	_save_settings()

func _on_reset_button_pressed() -> void:
	set_defaults()
	_save_settings()

func _on_back_pressed() -> void:
	_save_settings()
	get_tree().change_scene_to_file("res://Assets/Scenes/Menu/menu.tscn")

func set_defaults() -> void:
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	vibration_enabled = true
	left_handed_mode = false
	touch_controls_on_pc = false
	meme_mode_enabled = false

	_updating_ui = true
	master_slider.value = master_volume
	music_slider.value = music_volume
	sfx_slider.value = sfx_volume
	vibration_toggle.button_pressed = vibration_enabled
	left_handed_toggle.button_pressed = left_handed_mode
	touch_toggle.button_pressed = touch_controls_on_pc
	meme_mode_toggle.button_pressed = meme_mode_enabled
	_updating_ui = false

	_apply_audio_volumes()
	_update_audio_labels()
	apply_vibration_preview()
	update_touch_controls_layout()
	GlobalsSignals.set_meme_mode(meme_mode_enabled, false)
	update_touch_controls_visibility()
	update_touch_controls_skin()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	_master_bus_available = _bus_exists(MASTER_BUS)
	_music_bus_available = _bus_exists(MUSIC_BUS)
	_sfx_bus_available = _bus_exists(SFX_BUS)

	master_volume = clamp(cfg.get_value(SECTION_AUDIO, "master", _get_bus_linear(MASTER_BUS)), 0.0, 1.0)
	music_volume = clamp(cfg.get_value(SECTION_AUDIO, "music", _get_bus_linear(MUSIC_BUS)), 0.0, 1.0)
	sfx_volume = clamp(cfg.get_value(SECTION_AUDIO, "sfx", _get_bus_linear(SFX_BUS)), 0.0, 1.0)
	vibration_enabled = cfg.get_value(SECTION_GAMEPLAY, "vibration", true)
	left_handed_mode = cfg.get_value(SECTION_GAMEPLAY, "left_handed", false)
	meme_mode_enabled = cfg.get_value(SECTION_GAMEPLAY, "meme_mode", GlobalsSignals.get_meme_mode())
	touch_controls_on_pc = cfg.get_value(SECTION_GAMEPLAY, "show_touch_controls_desktop", GlobalsSignals.get_touch_controls_on_desktop())

	_updating_ui = true
	master_slider.editable = _master_bus_available
	music_slider.editable = _music_bus_available
	sfx_slider.editable = _sfx_bus_available
	music_row.visible = _music_bus_available
	sfx_row.visible = _sfx_bus_available
	master_slider.value = master_volume
	music_slider.value = music_volume
	sfx_slider.value = sfx_volume
	vibration_toggle.button_pressed = vibration_enabled
	left_handed_toggle.button_pressed = left_handed_mode
	touch_toggle.button_pressed = touch_controls_on_pc
	meme_mode_toggle.button_pressed = meme_mode_enabled
	_updating_ui = false
	GlobalsSignals.set_meme_mode(meme_mode_enabled, false)
	update_touch_controls_visibility()
	update_touch_controls_skin()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SECTION_AUDIO, "master", master_volume)
	cfg.set_value(SECTION_AUDIO, "music", music_volume)
	cfg.set_value(SECTION_AUDIO, "sfx", sfx_volume)
	cfg.set_value(SECTION_GAMEPLAY, "vibration", vibration_enabled)
	cfg.set_value(SECTION_GAMEPLAY, "left_handed", left_handed_mode)
	cfg.set_value(SECTION_GAMEPLAY, "show_touch_controls_desktop", touch_controls_on_pc)
	cfg.set_value(SECTION_GAMEPLAY, "meme_mode", meme_mode_enabled)
	cfg.save(SETTINGS_PATH)

func _apply_audio_volumes() -> void:
	if _master_bus_available:
		_apply_bus_volume(MASTER_BUS, master_volume)
	if _music_bus_available:
		_apply_bus_volume(MUSIC_BUS, music_volume)
	if _sfx_bus_available:
		_apply_bus_volume(SFX_BUS, sfx_volume)

func _apply_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	var db_value := _linear_to_db(linear_value)
	AudioServer.set_bus_volume_db(bus, db_value)
	AudioServer.set_bus_mute(bus, linear_value <= 0.0001)

func _update_audio_labels() -> void:
	_set_volume_label(master_label, master_slider.value, _master_bus_available)
	_set_volume_label(music_label, music_slider.value, _music_bus_available)
	_set_volume_label(sfx_label, sfx_slider.value, _sfx_bus_available)

func _set_volume_label(label: Label, value: float, available: bool) -> void:
	label.text = "N/A" if not available else "%d%%" % int(round(value * 100.0))

func apply_vibration_preview() -> void:
	if vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(0.05)

func update_touch_controls_layout() -> void:
	var controls := _find_touch_controls()
	if controls and controls.has_method("set_left_handed"):
		controls.set_left_handed(left_handed_mode)

func update_touch_controls_visibility() -> void:
	GlobalsSignals.set_touch_controls_on_desktop(touch_controls_on_pc, false)

func update_touch_controls_skin() -> void:
	var controls := _find_touch_controls()
	if controls and controls.has_method("set_skin_mode"):
		controls.set_skin_mode(meme_mode_enabled)

func _find_touch_controls() -> Node:
	var node := get_tree().get_first_node_in_group("touch_controls_ui")
	if node:
		return node
	return get_tree().root.find_child("touch_controls", true, false)

func _get_bus_linear(bus_name: String) -> float:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return 1.0
	return clamp(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.0, 1.0)

func _bus_exists(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) >= 0

func _linear_to_db(value: float) -> float:
	return -80.0 if value <= 0.0001 else linear_to_db(value)
