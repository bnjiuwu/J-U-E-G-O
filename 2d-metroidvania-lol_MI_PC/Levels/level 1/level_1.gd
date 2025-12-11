extends Node2D
class_name level1

@onready var touch_controls = $Controles/touch_controls

@export var pause_menu: CanvasLayer
@export var death_menu: CanvasLayer
@export var boss_node: NodePath
@export var next_level_index: int = 2
@export var next_level_path: String = "res://Levels/level 2/level_2.tscn"
@export var level_complete_delay: float = 2.5

@onready var animation_player: AnimationPlayer = $player/Camera2D/AnimationPlayer
var intro_shown: bool = false

@onready var boss_walls: TileMapLayer = $TileMaps/BossWalls

@onready var player: CharacterBody2D = $player
@onready var mini_map: CanvasLayer = $MiniMap
@onready var victory_label: Label = $VictoryCanvas/VictoryLabel

const DEFAULT_BOSS_PATH := NodePath("enemies/Kintama/Kintama")
const VICTORY_TEXT := "¡Felicidades!"

var _boss_instance: Node = null
var _level_complete_triggered: bool = false






func _physics_process(delta: float) -> void:
	
	
	pass
func _ready():
	# --- tu bloque fade intacto ---
	var fade_anim: Animation = animation_player.get_animation("fade")
	if fade_anim:
		fade_anim.loop_mode = Animation.LOOP_NONE
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play("fade")

	boss_walls.visible = false
	boss_walls.collision_enabled = false

	# ================================
	#  MENÚS: preferir LevelManager
	# ================================
	var manager := _find_level_manager()

	if manager:
		if pause_menu == null and manager.has_method("get_pause_menu"):
			pause_menu = manager.get_pause_menu()
		if death_menu == null and manager.has_method("get_death_menu"):
			death_menu = manager.get_death_menu()

	# fallback por grupo si no hay manager
	if pause_menu == null:
		pause_menu = get_tree().get_first_node_in_group("pause_menu")
	if death_menu == null:
		death_menu = get_tree().get_first_node_in_group("death_menu")

	# conectar muerte del jugador
	if player and death_menu:
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		print("✅ Death menu conectado correctamente al jugador")
	else:
		print("❌ Error: No se encontró el player o el death menu")

	print("🟩 level_1 listo")

	# pausa desde controles móviles
	if touch_controls and not touch_controls.pause_pressed.is_connected(_on_pause_button_pressed):
		touch_controls.pause_pressed.connect(_on_pause_button_pressed)

	if boss_node.is_empty():
		boss_node = DEFAULT_BOSS_PATH
	_connect_boss_signals()

	if victory_label:
		victory_label.visible = false

	if mini_map and player:
		mini_map.player_node = player


func _connect_boss_signals() -> void:
	var boss := get_node_or_null(boss_node) if not boss_node.is_empty() else null
	if boss == null:
		boss = _find_boss_candidate()
	if boss == null:
		push_warning("No se encontró el boss en %s" % boss_node)
		return
	_boss_instance = boss
	if boss.has_signal("boss_died") and not boss.boss_died.is_connected(_on_boss_died):
		boss.boss_died.connect(_on_boss_died)
	elif boss.has_signal("boss_defeated") and not boss.boss_defeated.is_connected(_on_boss_defeated):
		boss.boss_defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	_handle_level_completion()


func _on_boss_died(_boss_name: String = "") -> void:
	_handle_level_completion()


func _handle_level_completion() -> void:
	if _level_complete_triggered:
		return
	_level_complete_triggered = true

	_show_victory_message()

	# ✅ si es multi, avisar victoria al servidor
	if Network and Network.matchId != "" and Network.has_method("send_game_payload"):
		Network.send_game_payload({
			"type": "victory",
			"reason": "boss_defeated"
		})

	var delay: float = max(level_complete_delay, 0.0)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	_go_to_next_level()


func _go_to_next_level() -> void:
	var manager := _find_level_manager()
	if manager and manager.has_method("request_next_level"):
		manager.request_next_level()
		return
	if next_level_path.is_empty():
		push_warning("No hay ruta configurada para el siguiente nivel")
		return
	get_tree().change_scene_to_file(next_level_path)


func _find_level_manager() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var current := tree.current_scene
	if current and current != self and current.has_method("request_next_level"):
		return current
	var parent := get_parent()
	while parent:
		if parent.has_method("request_next_level"):
			return parent
		parent = parent.get_parent()
	return null

func _find_boss_candidate() -> Node:
	var candidate := get_tree().get_first_node_in_group("boss")
	if candidate:
		return candidate
	return get_node_or_null(DEFAULT_BOSS_PATH)

func _show_victory_message() -> void:
	if victory_label:
		victory_label.visible = true
		victory_label.text = VICTORY_TEXT

func _on_player_died() -> void:
	if Network and str(Network.matchId) != "":
		# En multi deja que lo maneje LevelManager
		return
	death_menu.show_death("¡HAS MUERTO!")



func _on_pause_button_pressed():
	print("🟢 Señal recibida en level_1 → abrir menú")

	# 1) Preferir LevelManager
	var manager := _find_level_manager()
	if manager and manager.has_method("toggle_pause"):
		manager.toggle_pause()
		return

	# 2) Fallback por variable export (si aún la usas)
	if pause_menu and pause_menu.has_method("toggle_pause"):
		pause_menu.toggle_pause()
		return

	# 3) Fallback por grupo (muy recomendado)
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if pm and pm.has_method("toggle_pause"):
		pm.toggle_pause()
		return

	push_warning("No pude encontrar PauseMenu para pausar.")

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"fade":
		print("Fade terminado, desactivando texto y AnimationPlayer")
		$player/Camera2D/Label2.visible = false   # opcional
		animation_player.stop()
		animation_player.playback_active = false  # 👈 ya no volverá a animar
