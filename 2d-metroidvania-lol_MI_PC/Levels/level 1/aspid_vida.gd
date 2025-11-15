extends Label

@onready var aspid = $".."

func _process(delta: float) -> void:
	self.text = str(aspid.health)
	
