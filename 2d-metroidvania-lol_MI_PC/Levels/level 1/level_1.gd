extends Node2D
class_name level1

@onready var touch_controls = $Controles/touch_controls

@export var player: CharacterBody2D
@export var pause_menu: CanvasLayer
@export var death_menu: CanvasLayer

@onready var animation_player: AnimationPlayer = $player/Camera2D/AnimationPlayer

@onready var boss_walls: TileMapLayer = $BossWalls # o TileMapLayer



func _physics_process(delta: float) -> void:
	animation_player.play("fade")
	
	pass
func _ready():

	boss_walls.visible = false
	boss_walls.collision_enabled = false

	if player and death_menu:
		player.died.connect(_on_player_died)
		print("✅ Death menu conectado correctamente al jugador")
	else:
		print("❌ Error: No se encontró el player o el death menu")

	print("🟩 level_1 listo")
	touch_controls.pause_pressed.connect(_on_pause_button_pressed)


func _on_player_died() -> void:
	print("💀 Jugador murió - Mostrando death menu")
	death_menu.show_death("¡HAS MUERTO!")

func _on_pause_button_pressed():
	print("🟢 Señal recibida en level_1 → abrir menú")
	pause_menu.toggle_pause()
