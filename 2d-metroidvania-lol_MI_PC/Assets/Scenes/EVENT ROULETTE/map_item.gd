extends Node2D
class_name MapCaseObject


@export var roulette_type: String = ""  # opcional, por si quieres diferenciar en el futuro
var used := false

@onready var anim: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var area: Area2D = $Area2D
@onready var col: CollisionShape2D = $Area2D/CollisionShape2D



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# ✅ reproduce una sola vez
	if anim and anim.has_animation("spin"):
		anim.play("spin")

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	if used:
		return
	if body == null or not body.is_in_group("player"):
		return

	used = true

	# ✅ pedir ruleta al LevelManager (gateway)
	var lm := get_tree().get_first_node_in_group("level_manager")
	if lm:

		# Si ya tienes el gateway central:
		if lm.has_method("trigger_roulette"):
			lm.trigger_roulette(roulette_type, 0, false)  # sin daño, sin countdown obligatorio
		# Si mantienes request_roulette:
		elif lm.has_method("request_roulette"):
			lm.request_roulette(roulette_type)
		else:
			push_warning("LevelManager no tiene API de ruleta conocida.")
	else:
		push_warning("No encontré LevelManager en grupo 'level_manager'.")

	# ✅ evitar re-activación aunque el nodo quede vivo
	if col:
		col.disabled = true

	# opcional: destruir caja tras usarla
	queue_free()
	pass # Replace with function body.
