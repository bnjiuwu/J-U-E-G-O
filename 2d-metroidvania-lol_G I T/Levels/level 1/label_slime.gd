extends Label

@onready var slime = $".."

func _process(delta: float) -> void:
	self.text = str(slime.health)
	
