extends Node2D
class_name level1

@onready var touch_controls = $Controles/touch_controls

@export var pause_menu: CanvasLayer
@export var death_menu: CanvasLayer

@onready var animation_player: AnimationPlayer = $player/Camera2D/AnimationPlayer
var intro_shown: bool = false

@onready var boss_walls: TileMapLayer = $TileMaps/BossWalls

@onready var player: CharacterBody2D = $player
@onready var mini_map: CanvasLayer = $MiniMap



func _physics_process(delta: float) -> void:
	
	
	pass
func _ready():
	# --- DEBUG + FORZAR SIN LOOP ---
	var fade_anim: Animation = animation_player.get_animation("fade")
	if fade_anim:
		fade_anim.loop_mode = Animation.LOOP_NONE   # 👈 forzamos sin loop
		print("FADE loop_mode =", fade_anim.loop_mode)  # debería ser 0 (LOOP_NONE)

	# Conectar señal para saber cuándo termina
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

	# Reproducir SOLO aquí
	animation_player.play("fade")

	boss_walls.visible = false
	boss_walls.collision_enabled = false

	if player and death_menu:
		player.died.connect(_on_player_died)
		print("✅ Death menu conectado correctamente al jugador")
	else:
		print("❌ Error: No se encontró el player o el death menu")

	print("🟩 level_1 listo")
	touch_controls.pause_pressed.connect(_on_pause_button_pressed)
	
	if mini_map and player:
		mini_map.player_node = player
		pass
	

func _on_player_died() -> void:
	print("💀 Jugador murió - Mostrando death menu")
	death_menu.show_death("¡HAS MUERTO!")

func _on_pause_button_pressed():
	print("🟢 Señal recibida en level_1 → abrir menú")
	pause_menu.toggle_pause()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"fade":
		print("Fade terminado, desactivando texto y AnimationPlayer")
		$player/Camera2D/Label2.visible = false   # opcional
		animation_player.stop()
		animation_player.playback_active = false  # 👈 ya no volverá a animar
