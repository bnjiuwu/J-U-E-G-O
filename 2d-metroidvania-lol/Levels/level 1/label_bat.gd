extends Label

@onready var bat = $".."

func _process(delta: float) -> void:
	self.text = str(bat.health)
	
