extends Node2D
class_name CaseItem

@export var duration: float 
@onready var timer: Timer = $Timer

func apply_to(player: Node) -> void:
	if not timer:
		return

	timer.one_shot = true
	timer.wait_time = duration

	_on_apply(player)

	timer.timeout.connect(func():
		if is_instance_valid(player):
			_on_expire(player)
	, CONNECT_ONE_SHOT)

	timer.start()

func _on_apply(player: Node) -> void:
	pass

func _on_expire(player: Node) -> void:
	pass
