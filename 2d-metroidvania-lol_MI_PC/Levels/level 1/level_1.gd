extends Node2D

@onready var touch_controls = $Controles/touch_controls
@export var player: CharacterBody2D
@export var pause_menu: CanvasLayer
@export var death_menu: CanvasLayer

func _ready():
	# Conectar la señal de muerte del jugador con el death menu
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
