extends Area2D
class_name BossRoomTrigger

@onready var camera_2d: Camera2D = $"../../player/Camera2D"

@export var boss_walls: TileMapLayer
@export var boss_node: NodePath
@export var reopen_when_boss_dies: bool = true

var activated := false
var _boss_instance: Node = null

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_connect_boss_signals()
	_set_walls_enabled(false)

func _connect_boss_signals() -> void:
	if boss_node.is_empty():
		return
	if _boss_instance and is_instance_valid(_boss_instance):
		return
	_boss_instance = get_node_or_null(boss_node)
	if _boss_instance and reopen_when_boss_dies and _boss_instance.has_signal("boss_died"):
		if not _boss_instance.boss_died.is_connected(_on_boss_died):
			_boss_instance.boss_died.connect(_on_boss_died)

func _set_walls_enabled(state: bool) -> void:
	if not boss_walls:
		return
	boss_walls.visible = state
	boss_walls.enabled = state
	boss_walls.collision_enabled = state

func _on_boss_died(_boss_name: String) -> void:
	_set_walls_enabled(false)
	activated = false
	monitoring = false
	monitorable = false

func _on_body_entered(body: Node2D) -> void:
	if activated:
		return
	if not body.is_in_group("player"):
		return

	camera_2d.set_zoom(Vector2(1.0, 1.0))
	activated = true
	print("🔥 BossRoomTrigger activado")
	_set_walls_enabled(true)

	monitoring = false
	monitorable = false
