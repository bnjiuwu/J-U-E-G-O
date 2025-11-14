extends CanvasLayer

@onready var button_pause = $pause_button
signal pause_pressed

func _ready():
	button_pause.pressed.connect(_on_pause_button_pressed)

func _on_pause_button_pressed() -> void:
	print("🟡 Pausa tocada")
	emit_signal("pause_pressed")
	
