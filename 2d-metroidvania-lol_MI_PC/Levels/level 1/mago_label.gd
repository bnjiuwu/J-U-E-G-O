extends Label

@onready var mago = $".."

func _process(delta: float) -> void:
	self.text = str(mago.health)
	
