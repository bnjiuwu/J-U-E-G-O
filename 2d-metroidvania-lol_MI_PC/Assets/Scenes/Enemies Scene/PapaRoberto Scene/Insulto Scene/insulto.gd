extends Area2D

@export var speed: float = 150.0
@export var damage: int = 15
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var insult_text: String = ""

@onready var label: Label = $InsultBubble/Label
@onready var bubble: NinePatchRect = $InsultBubble

var insults_list = [
	"$#@%!",
	"&*@#!",
	"@$%*!",
	"#&@!",
	"*$#@!",
	"@%&*!",
	"$*@#!",
	"&#%@!"
]

func _ready():
	# Seleccionar un insulto aleatorio
	insult_text = insults_list[randi() % insults_list.size()]
	label.text = insult_text
	
	# Configurar el tiempo de vida
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_expired)
	add_child(timer)
	timer.start()
	
	# Conectar señal de colisión
	body_entered.connect(_on_body_entered)
	
	print("💬 Papá Roberto gritó: " + insult_text)

func _physics_process(delta):
	# Mover el proyectil
	global_position += direction * speed * delta
	
	# Efecto de flotación (como globo de texto)
	global_position.y -= 20 * delta

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Aplicar daño al jugador
		if body.has_method("take_damage"):
			body.take_damage(damage)
			print("💥 ¡El insulto hirió al jugador por " + str(damage) + " de daño!")
		queue_free()
		
	if body.is_in_group("world colition"):
		print("💥 Bala chocó con pared")
		queue_free()

func _on_lifetime_expired():
	# El insulto se desvanece
	print("💭 El insulto '" + insult_text + "' se desvaneció...")
	queue_free()
