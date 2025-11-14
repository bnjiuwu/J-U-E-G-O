extends Node2D

@export var niveles: Array[PackedScene]

var _nivel_actual: int = 1
var _nivel_instanciado: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_crear_nivel(_nivel_actual )
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _crear_nivel(numero_nivel: int):
	_nivel_instanciado = niveles[numero_nivel - 1].instantiate()
	add_child(_nivel_instanciado)
	
	var player := get_tree().get_nodes_in_group("player")
	player[0].dead.connect(_reiniciar_nivel())
	
	
	pass
func _eliminar_nivel():
	_nivel_instanciado.queue_free()
	
	
func _reiniciar_nivel():
	_eliminar_nivel()
	_crear_nivel(_nivel_actual)
