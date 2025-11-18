extends Label

@onready var aspid := get_parent()

func _process(_delta: float) -> void:
	if not is_instance_valid(aspid):
		return
	text = str(aspid.health)
