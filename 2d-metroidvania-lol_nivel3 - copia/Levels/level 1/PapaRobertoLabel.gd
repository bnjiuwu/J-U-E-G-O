extends Label

@onready var papaR = $".."

func _process(_delta: float) -> void:
	self.text = str(papaR.health)
	
