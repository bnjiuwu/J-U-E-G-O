extends Label


@onready var player = $"../.."

func _process(_delta: float) -> void:
	self.text = str(player.health)
	pass
