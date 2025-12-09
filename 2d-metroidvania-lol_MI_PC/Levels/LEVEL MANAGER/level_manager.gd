# res://Scripts/level_manager.gd
extends Node2D

@export var niveles: Array[PackedScene] = []
@export_file("*.tscn") var fallback_scene: String = "res://Assets/Scenes/Menu/menu.tscn"

var _nivel_actual: int = 1
var _nivel_instanciado: Node = null

@onready var _loading_screen: Control = $CanvasLayer/LoadingScreen

var _cargando: bool = false
var _nivel_path_cargando: String = ""
var _progreso := [0.0]

var _min_display_time := 0.5
var _display_time := 0.0

func _ready() -> void:
	print("level_manager listo")
	if niveles.is_empty():
		push_error("No hay niveles asignados en 'niveles'.")
		return

	if _loading_screen == null:
		push_error("No encontré CanvasLayer/LoadingScreen.")
	else:
		_loading_screen.visible = false

	_cargar_nivel_async(_nivel_actual)


func _process(delta: float) -> void:
	if not _cargando:
		return

	_display_time += delta

	var status := ResourceLoader.load_threaded_get_status(_nivel_path_cargando, _progreso)

	# DEBUG: ver el progreso en la consola
	# (deberías ver números entre 0 y 1)
	print("progreso carga: ", _progreso[0])

	if is_instance_valid(_loading_screen):
		_loading_screen.call("set_progress", _progreso[0])

	match status:
		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
			pass

		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_FAILED:
			push_error("Falló la carga del nivel: %s" % _nivel_path_cargando)
			_cargando = false
			_ocultar_pantalla_carga()

		ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
			# Esperar al menos un ratito para poder VER la barra
			if _display_time < _min_display_time:
				return

			var scene_res: PackedScene = ResourceLoader.load_threaded_get(_nivel_path_cargando)
			if scene_res:
				_instanciar_nivel(scene_res)
			else:
				push_error("No se pudo obtener PackedScene de %s" % _nivel_path_cargando)

			_cargando = false
			_nivel_path_cargando = ""
			_ocultar_pantalla_carga()


func _cargar_nivel_async(numero_nivel: int) -> void:
	if numero_nivel < 1 or numero_nivel > niveles.size():
		push_error("Número de nivel fuera de rango: %d" % numero_nivel)
		if numero_nivel > niveles.size():
			_handle_all_levels_complete()
		return

	_nivel_actual = numero_nivel
	_eliminar_nivel()

	_mostrar_pantalla_carga()
	_display_time = 0.0

	var packed: PackedScene = niveles[numero_nivel - 1]
	_nivel_path_cargando = packed.resource_path
	print("Cargando nivel path: ", _nivel_path_cargando)

	if _nivel_path_cargando == "":
		push_error("El PackedScene del nivel %d no tiene resource_path válido." % numero_nivel)
		_ocultar_pantalla_carga()
		return

	_progreso[0] = 0.0
	_cargando = true

	var err := ResourceLoader.load_threaded_request(_nivel_path_cargando)
	if err != OK:
		push_error("No se pudo iniciar load_threaded_request: %s" % _nivel_path_cargando)
		_cargando = false
		_ocultar_pantalla_carga()


func request_next_level() -> void:
	var siguiente := _nivel_actual + 1
	if siguiente > niveles.size():
		_handle_all_levels_complete()
		return
	_cargar_nivel_async(siguiente)


func request_level(index: int) -> void:
	_cargar_nivel_async(index)


func _instanciar_nivel(packed: PackedScene) -> void:
	_nivel_instanciado = packed.instantiate()
	add_child(_nivel_instanciado)

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		push_warning("No se encontró ningún nodo en el grupo 'player'.")
		return

	var player = players[0]



func _eliminar_nivel() -> void:
	if is_instance_valid(_nivel_instanciado):
		_nivel_instanciado.queue_free()
		_nivel_instanciado = null


func _reiniciar_nivel() -> void:
	_cargar_nivel_async(_nivel_actual)


func _mostrar_pantalla_carga() -> void:
	if is_instance_valid(_loading_screen):
		_loading_screen.visible = true
		_loading_screen.call("set_progress", 0.0)


func _ocultar_pantalla_carga() -> void:
	if is_instance_valid(_loading_screen):
		_loading_screen.visible = false


func _handle_all_levels_complete() -> void:
	print("✅ Todos los niveles han sido completados")
	if fallback_scene.is_empty():
		return
	var tree := get_tree()
	if tree:
		tree.change_scene_to_file(fallback_scene)
