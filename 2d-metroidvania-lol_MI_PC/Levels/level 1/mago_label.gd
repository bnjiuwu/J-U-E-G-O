extends Label

@onready var mago = $".."

func _process(_delta: float) -> void:
	self.text = str(mago.health)
	
