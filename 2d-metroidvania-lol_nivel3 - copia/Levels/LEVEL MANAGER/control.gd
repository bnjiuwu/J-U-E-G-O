# res://Scripts/LoadingScreen.gd
extends Control

@onready var progress_bar: ProgressBar = $ProgressBar

func _ready() -> void:
	# Para probar que existe el nodo
	if progress_bar == null:
		push_error("No encontré ProgressBar como hijo de LoadingScreen")
	visible = false  # arranca oculta

func set_progress(t: float) -> void:
	# t viene entre 0.0 y 1.0
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = clamp(t * 100.0, 0.0, 100.0)
