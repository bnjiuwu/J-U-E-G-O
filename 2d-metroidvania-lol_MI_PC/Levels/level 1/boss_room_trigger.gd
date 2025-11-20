extends Area2D
class_name BossRoomTrigger

@onready var camera_2d: Camera2D = $"../../player/Camera2D"

@export var boss_walls: TileMapLayer

var activated := false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)



	# Tilemap del boss apagado al inicio (por si no lo haces en level_1)
	if boss_walls:
		boss_walls.enabled = false
		boss_walls.collision_enabled = false


func _on_body_entered(body: Node2D) -> void:
	if activated:
		return
	if not body.is_in_group("player"):
		return

	camera_2d.set_zoom(Vector2(1.0,1.0))
	activated = true
	print("🔥 BossRoomTrigger activado")

	# Activar tilemap del boss (gráfico + colisión)
	if boss_walls:
		boss_walls.enabled = true
		boss_walls.visible = true
		boss_walls.collision_enabled = true

	monitoring = false
	monitorable = false
