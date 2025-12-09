extends Node

# Esta señal se emitirá cada vez que muera un enemigo
signal enemy_defeated
signal meme_mode_changed(enabled: bool)
signal touch_controls_visibility_changed(show_on_desktop: bool)

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_GAMEPLAY := "gameplay"
const MEME_KEY := "meme_mode"
const TOUCH_CONTROLS_DESKTOP_KEY := "show_touch_controls_desktop"

var meme_mode_enabled: bool = false
var touch_controls_on_desktop: bool = false

func _ready() -> void:
	_load_meme_mode()
	_load_touch_controls_pref()
	meme_mode_changed.emit(meme_mode_enabled)
	touch_controls_visibility_changed.emit(touch_controls_on_desktop)

func set_meme_mode(enabled: bool, persist: bool = true) -> void:
	if meme_mode_enabled == enabled:
		if persist:
			_save_meme_mode() # Asegura que el archivo exista incluso si aún no hay entrada
		return
	meme_mode_enabled = enabled
	if persist:
		_save_meme_mode()
	meme_mode_changed.emit(meme_mode_enabled)

func get_meme_mode() -> bool:
	return meme_mode_enabled

func set_touch_controls_on_desktop(enabled: bool, persist: bool = true) -> void:
	if touch_controls_on_desktop == enabled:
		if persist:
			_save_touch_controls_pref()
		return
	touch_controls_on_desktop = enabled
	if persist:
		_save_touch_controls_pref()
	touch_controls_visibility_changed.emit(touch_controls_on_desktop)

func get_touch_controls_on_desktop() -> bool:
	return touch_controls_on_desktop

func _load_meme_mode() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	meme_mode_enabled = cfg.get_value(SECTION_GAMEPLAY, MEME_KEY, false)

func _save_meme_mode() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SECTION_GAMEPLAY, MEME_KEY, meme_mode_enabled)
	cfg.save(SETTINGS_PATH)

func _load_touch_controls_pref() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return
	touch_controls_on_desktop = cfg.get_value(SECTION_GAMEPLAY, TOUCH_CONTROLS_DESKTOP_KEY, false)

func _save_touch_controls_pref() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SECTION_GAMEPLAY, TOUCH_CONTROLS_DESKTOP_KEY, touch_controls_on_desktop)
	cfg.save(SETTINGS_PATH)
