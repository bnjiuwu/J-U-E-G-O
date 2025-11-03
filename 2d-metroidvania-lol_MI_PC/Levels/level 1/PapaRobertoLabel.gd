extends Label

@onready var papaR = $".."

func _process(delta: float) -> void:
	self.text = str(papaR.health)
	
