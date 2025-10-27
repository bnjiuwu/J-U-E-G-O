extends Node2D

@onready var touch_controls = $Controles/touch_controls
@onready var pause_menu = $PauseMenu

func _ready():
	print("🟩 level_1 listo")
	touch_controls.pause_pressed.connect(_on_pause_button_pressed)

func _on_pause_button_pressed():
	print("🟢 Señal recibida en level_1 → abrir menú")
	pause_menu.toggle_pause()
