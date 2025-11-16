extends Label

@onready var slime = $".."

func _process(_delta: float) -> void:
	self.text = str(slime.health)
	
