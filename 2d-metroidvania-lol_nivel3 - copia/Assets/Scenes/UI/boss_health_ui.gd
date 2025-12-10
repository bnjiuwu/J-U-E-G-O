extends Control
class_name BossHealthUI

@export var boss_path: NodePath
@export var hide_after_death_delay: float = 2.5
@export var follow_boss: bool = false
@export var follow_screen_offset: Vector2 = Vector2(0, -200)
@export var clamp_to_viewport: bool = true
@export var screen_margin: Vector2 = Vector2(32, 32)

@onready var _value_label: Label = %ValueLabel

var _boss: Node = null
var _hide_timer: SceneTreeTimer = null
var _boss_visible: bool = false
var _force_visible: bool = false
var _current_health: int = 0
var _max_health: int = 0

func _ready() -> void:
	visible = false
	_value_label.text = "0 / 0"
	call_deferred("_attempt_connect")

func _process(_delta: float) -> void:
	if follow_boss:
		_update_follow_position()

func _attempt_connect() -> void:
	if boss_path.is_empty():
		return
	var boss_node: Node = get_node_or_null(boss_path)
	if boss_node:
		_attach_to_boss(boss_node)

func _attach_to_boss(boss: Node) -> void:
	_boss = boss
	if boss.has_signal("boss_health_changed") and not boss.boss_health_changed.is_connected(_on_boss_health_changed):
		boss.boss_health_changed.connect(_on_boss_health_changed)
	if boss.has_signal("boss_died") and not boss.boss_died.is_connected(_on_boss_died):
		boss.boss_died.connect(_on_boss_died)
	if boss.has_signal("boss_visibility_changed") and not boss.boss_visibility_changed.is_connected(_on_boss_visibility_changed):
		boss.boss_visibility_changed.connect(_on_boss_visibility_changed)
	if boss.has_method("is_visible_to_player"):
		_boss_visible = bool(boss.call("is_visible_to_player"))
	var current_health: int = int(boss.call("get_current_health")) if boss.has_method("get_current_health") else 0
	var max_value: int = int(boss.call("get_max_health_value")) if boss.has_method("get_max_health_value") else 0
	if follow_boss:
		_update_follow_position()
	_on_boss_health_changed(current_health, max_value)

func _on_boss_health_changed(current: int, max_value: int, _boss_name_unused: String = "") -> void:
	if _hide_timer != null:
		_hide_timer = null
		_force_visible = false
	_max_health = max(max_value, 0)
	if _max_health <= 0:
		_current_health = 0
		_value_label.text = "0 / 0"
	else:
		_current_health = clamp(current, 0, _max_health)
		_value_label.text = "%d / %d" % [_current_health, _max_health]
	_update_visibility()

func _on_boss_died(_boss_name_unused: String) -> void:
	_on_boss_health_changed(0, _max_health)
	_force_visible = true
	_update_visibility()
	if hide_after_death_delay <= 0.0:
		visible = false
		return
	_hide_timer = get_tree().create_timer(hide_after_death_delay)
	_hide_timer.timeout.connect(_on_hide_timeout, Object.CONNECT_ONE_SHOT)

func _on_hide_timeout() -> void:
	_force_visible = false
	_update_visibility()

func _on_boss_visibility_changed(is_visible: bool) -> void:
	_boss_visible = is_visible
	if not _force_visible:
		_update_visibility()
	if _boss_visible and follow_boss:
		_update_follow_position()

func _update_visibility() -> void:
	visible = (_boss_visible or _force_visible) and _max_health > 0

func _update_follow_position() -> void:
	if not follow_boss:
		return
	if _boss == null or not is_instance_valid(_boss):
		return
	var boss_node := _boss as Node2D
	if boss_node == null:
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var camera := viewport.get_camera_2d()
	if camera == null:
		return
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	var viewport_size: Vector2 = viewport_rect.size
	var zoom: Vector2 = camera.zoom
	var zoom_safe := Vector2(max(zoom.x, 0.001), max(zoom.y, 0.001))
	var half_view: Vector2 = (viewport_size * 0.5) * zoom
	var top_left: Vector2 = camera.global_position - half_view
	var relative_position: Vector2 = boss_node.global_position - top_left
	var screen_position: Vector2 = Vector2(
		relative_position.x / zoom_safe.x,
		relative_position.y / zoom_safe.y
	)
	if clamp_to_viewport:
		var min_pos := screen_margin
		var max_pos := viewport_size - screen_margin
		screen_position.x = clampf(screen_position.x, min_pos.x, max_pos.x)
		screen_position.y = clampf(screen_position.y, min_pos.y, max_pos.y)
	position = screen_position + follow_screen_offset
