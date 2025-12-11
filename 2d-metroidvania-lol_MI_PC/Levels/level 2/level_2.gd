extends Node2D
class_name level2

@export var golem_path: NodePath = NodePath("Golem")
@export var next_level_path: String = "res://Levels/level 3/level_3.tscn"
@export var level_complete_delay: float = 2.0
@export var victory_label_path: NodePath = NodePath("VictoryCanvas/VictoryLabel")
@export var victory_text: String = "¡Felicidades!"

# Variables internas
var _level_complete_triggered: bool = false
var _victory_label: Label
var _boss_instance: Node = null

# Referencias a menús
var pause_menu: Node = null
var death_menu: Node = null
var player: Node = null

func _ready() -> void:
	# 1. Configurar Golem
	var golem := get_node_or_null(golem_path)
	if golem:
		_boss_instance = golem
		if golem.has_signal("boss_died") and not golem.boss_died.is_connected(_on_golem_died):
			golem.boss_died.connect(_on_golem_died)
	else:
		push_warning("⚠️ Nivel 2: No se encontró el Golem")

	# 2. Configurar Label de Victoria
	_victory_label = get_node_or_null(victory_label_path)
	if _victory_label:
		_victory_label.visible = false

	# 3. Buscar Player
	player = get_tree().get_first_node_in_group("player")
	
	# ================================
	#  GESTIÓN DE MENÚS (LevelManager)
	# ================================
	var manager = _find_level_manager()

	if manager:
		if pause_menu == null and manager.has_method("get_pause_menu"):
			pause_menu = manager.get_pause_menu()
		if death_menu == null and manager.has_method("get_death_menu"):
			death_menu = manager.get_death_menu()

	# Fallback por grupo si no hay manager
	if pause_menu == null:
		pause_menu = get_tree().get_first_node_in_group("pause_menu")
	if death_menu == null:
		death_menu = get_tree().get_first_node_in_group("death_menu")

	# 4. Conectar muerte del jugador
	if player and death_menu:
		if player.has_signal("died"):
			if not player.died.is_connected(_on_player_died):
				player.died.connect(_on_player_died)
		print("✅ Nivel 2: Death menu conectado correctamente al jugador")
	else:
		push_warning("⚠️ Nivel 2: No se encontró Player o DeathMenu.")

	# 5. Configurar controles táctiles
	var touch_controls := get_node_or_null("Controles/touch_controls")
	if touch_controls and touch_controls.has_signal("pause_pressed"):
		if not touch_controls.pause_pressed.is_connected(_on_pause_button_pressed):
			touch_controls.pause_pressed.connect(_on_pause_button_pressed)

	print("🟩 level_2 listo")


func _on_golem_died(_boss_name: String = "") -> void:
	if _level_complete_triggered:
		return
	_level_complete_triggered = true
	
	_show_victory_message()

	# SOPORTE MULTIJUGADOR
	if Network and Network.matchId != "" and Network.has_method("send_game_payload"):
		Network.send_game_payload({
			"type": "victory",
			"reason": "golem_defeated"
		})
	
	await _run_level_complete_flow()


func _run_level_complete_flow() -> void:
	if level_complete_delay > 0.0:
		await get_tree().create_timer(level_complete_delay).timeout
	_go_to_next_level()


func _go_to_next_level() -> void:
	var manager = _find_level_manager()
	if manager and manager.has_method("request_next_level"):
		manager.request_next_level()
		return
	
	if next_level_path.is_empty():
		push_warning("⚠️ Nivel 2: next_level_path vacío.")
		return
		
	get_tree().change_scene_to_file(next_level_path)


func _find_level_manager() -> Node:
	var tree := get_tree()
	if tree:
		var mgr := tree.get_first_node_in_group("level_manager")
		if mgr: return mgr
		
		var current := tree.current_scene
		if current and current != self and current.has_method("request_next_level"):
			return current

	var parent := get_parent()
	while parent:
		if parent.is_in_group("level_manager") or parent.has_method("request_next_level"):
			return parent
		parent = parent.get_parent()
	return null


func _show_victory_message() -> void:
	if _victory_label:
		_victory_label.text = victory_text
		_victory_label.visible = true


func _on_player_died() -> void:
	if Network and str(Network.matchId) != "":
		return

	print("💀 Jugador murió (Nivel 2) - Mostrando death menu")
	if death_menu and death_menu.has_method("show_death"):
		death_menu.show_death("¡HAS MUERTO!")


func _on_pause_button_pressed() -> void:
	var manager = _find_level_manager()
	if manager and manager.has_method("toggle_pause"):
		manager.toggle_pause()
		return

	if pause_menu and pause_menu.has_method("toggle_pause"):
		pause_menu.toggle_pause()
		return
		
	push_warning("⚠️ Nivel 2: No se encontró PauseMenu para pausar.")
