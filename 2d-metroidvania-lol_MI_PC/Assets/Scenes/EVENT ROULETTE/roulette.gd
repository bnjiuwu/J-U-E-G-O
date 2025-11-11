extends Control

@export var scroll_speed: float = 900.0    # velocidad horizontal
@export var scroll_time: float = 2.0       # tiempo total antes de detenerse

@onready var strip: HBoxContainer = $HBoxContainer
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var indicator: Sprite2D = $"Black Line"

var is_scrolling := false
var stop_target_x := 0.0
var stopping := false

var rarities = [
	{"name": "blue", "weight": 50},
	{"name": "purple", "weight": 30},
	{"name": "pink", "weight": 15},
	{"name": "red", "weight": 4},
	{"name": "gold", "weight": 1}
]

func _ready():
	is_scrolling = true
	anim.play("scroll_start")
	
	# luego de X segundos, elegimos raro
	await get_tree().create_timer(scroll_time).timeout
	_stop_on_random_rarity()

func _process(delta):
	if is_scrolling:
		strip.position.x -= scroll_speed * delta

	# Movimiento de “detención”
	if stopping:
		# mueve la tira hasta alinearse con stop_target_x
		var diff = stop_target_x - strip.position.x
		if abs(diff) < 20:			
			strip.position.x = stop_target_x
			stopping = false
			print("🎉 FINAL:", get_selected_rarity())
		else:
			strip.position.x += diff * 5 * delta # frena suavemente SIN TWEEN

func _stop_on_random_rarity():
	is_scrolling = false

	var selected = _weighted_random()
	var node := strip.get_node(selected["name"])

	# Queremos que ese sprite quede JUSTO bajo el indicador
	var indicator_x = indicator.global_position.x
	var target_x = indicator_x - node.global_position.x

	stop_target_x = strip.position.x + target_x
	stopping = true

func _weighted_random():
	var total = 0
	for r in rarities:
		total += r["weight"]

	var roll = randi() % total
	var cum = 0

	for r in rarities:
		cum += r["weight"]
		if roll < cum:
			return r

	return rarities[0]  # fallback

func get_selected_rarity() -> String:
	for r in rarities:
		if strip.get_node(r["name"]).global_position.x == indicator.global_position.x:
			return r["name"]
	return "Unknown"
