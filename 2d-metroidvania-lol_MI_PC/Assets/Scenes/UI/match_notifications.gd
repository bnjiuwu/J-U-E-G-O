extends CanvasLayer
class_name MatchNotifications

@onready var label: Label = $Label

var _version: int = 0
var _notif_token: int = 0

func show_notification(text: String, seconds: float = 5.0) -> void:
	_notif_token += 1
	var token := _notif_token

	var lbl := get_tree().get_first_node_in_group("match_notification_ui")
	if lbl is Label:
		lbl.visible = true
		lbl.text = text

	await get_tree().create_timer(seconds).timeout

	if token != _notif_token:
		return

	lbl = get_tree().get_first_node_in_group("match_notification_ui")
	if lbl is Label and is_instance_valid(lbl):
		lbl.visible = false

func _ready() -> void:
	if label:
		label.visible = false

func show_msg(text: String, seconds: float = 5.0) -> void:
	if label == null:
		return

	_version += 1
	var v := _version

	label.text = text
	label.visible = true

	var t := get_tree().create_timer(seconds, true)
	t.timeout.connect(func():
		# ✅ si llegó otra notificación luego, ignoramos este hide viejo
		if v != _version:
			return
		if label and is_instance_valid(label):
			label.visible = false
	, CONNECT_ONE_SHOT)
