extends Label


@onready var player = $"../.."

func _process(delta: float) -> void:
	self.text = str(player.health)
	pass
