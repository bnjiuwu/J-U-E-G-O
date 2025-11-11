extends Node2D

# ---------------------------
# CONFIGURACIÓN
# ---------------------------
const SLOT_W := 225.0
const SLOT_H := 225.0
const CENTER_Y := 240.0
const VIEW_CENTER_X := 480.0

@export var items_to_generate := 40
@export var base_tick_time := 0.03     # velocidad inicial
@export var tick_growth := 1.12        # curva de desaceleración
@export var extra_ticks := 30          # vueltas antes del objetivo

# ---------------------------
# NODOS
# ---------------------------
@onready var scroll := $Scroll
@onready var slots := $Scroll/Slots
@onready var slots_dup := $Scroll/SlotsDuplicate
@onready var indicator := $Indicator

# ---------------------------
# VARIABLES
# ---------------------------
var full_strip_width: float
var target_name: String
var target_index: int
var final_slot_index: int
var current_index: int = 0

var tick_time: float
var spinning: bool = false

var rarities := [
	{"name":"blue",   "weight":50, "texture": preload("res://Assets/sprites/EVENT ROULETTE/blue.png")},
	{"name":"purple", "weight":30, "texture": preload("res://Assets/sprites/EVENT ROULETTE/purple.png")},
	{"name":"pink",   "weight":15, "texture": preload("res://Assets/sprites/EVENT ROULETTE/pink.png")},
	{"name":"red",    "weight": 4, "texture": preload("res://Assets/sprites/EVENT ROULETTE/red.png")},
	{"name":"gold",   "weight": 1, "texture": preload("res://Assets/sprites/EVENT ROULETTE/yellow.png")}
]

# =========================================================
# READY
# =========================================================
func _ready():
	generate_slots()
	await get_tree().process_frame
	start_spin()
	print("----- DEBUG ORIGEN -----")
	print("Roulette pos:", global_position)
	print("Scroll pos:", scroll.position, "Scroll global:", scroll.global_position)
	print("Indicator pos:", indicator.position, "Indicator global:", indicator.global_position)
	print("Parent:", get_parent())



# =========================================================
# GENERAR RUNA DE SLOTS
# =========================================================
func generate_slots():
	var x := 0.0

	# full width exacto, sin trucos, sin spacing extra
	full_strip_width = SLOT_W * items_to_generate

	for i in range(items_to_generate):
		var d = weighted_random()
		var tex: Texture2D = d["texture"]

		var s := Sprite2D.new()
		s.texture = tex
		s.position = Vector2(x + SLOT_W * 0.5, CENTER_Y)
		s.name = d["name"]
		slots.add_child(s)

		x += SLOT_W

	# duplicado exacto
	for child: Sprite2D in slots.get_children():
		var clone := Sprite2D.new()
		clone.texture = child.texture
		clone.name = child.name
		clone.position = child.position + Vector2(full_strip_width, 0)
		slots_dup.add_child(clone)

# =========================================================
# RANDOM PONDERADO
# =========================================================
func weighted_random() -> Dictionary:
	var total := 0
	for r in rarities:
		total += r["weight"]
	var roll := randi() % total
	var acc := 0
	for r in rarities:
		acc += r["weight"]
		if roll < acc:
			return r
	return rarities[0]

# =========================================================
# Elegir objetivo antes de girar
# =========================================================
func choose_target():
	var chosen = weighted_random()
	target_name = chosen["name"]
	print("🎯 Objetivo elegido:", target_name)

	# buscar el PRIMER slot que coincida
	var index := 0
	for s in slots.get_children():
		if s.name == target_name:
			target_index = index
			return
		index += 1

# =========================================================
# INICIAR SPIN
# =========================================================
func start_spin():
	scroll.position = Vector2.ZERO
	choose_target()

	# Queremos varias vueltas antes de caer en objetivo
	final_slot_index = target_index + extra_ticks
	current_index = 0

	# Reset posición
	scroll.position.x = 0
	tick_time = base_tick_time

	spinning = true
	spin_tick()

# =========================================================
# TICK — mover 1 slot por paso
# =========================================================
func spin_tick():
	if not spinning:
		return

	# mover 1 casilla a la izquierda
	scroll.position.x -= SLOT_W

	# wrap infinito
	if scroll.position.x <= -full_strip_width:
		scroll.position.x += full_strip_width

	current_index += 1

	if current_index >= final_slot_index:
		# detener EXACTAMENTE en target
		align_exact()
		return

	# aumentar delay (desaceleración tipo ease-out)
	tick_time *= tick_growth

	# siguiente tick
	await get_tree().create_timer(tick_time).timeout
	spin_tick()

# =========================================================
# Alinear EXACTO sin correcciones extrañas
# =========================================================
func align_exact():
	spinning = false
	print("🏁 GANADOR:", target_name)
	apply_reward(target_name)

# =========================================================
# Recompensa final
# =========================================================
func apply_reward(n):
	match n:
		"blue": print("→ Recompensa común")
		"purple": print("→ Recompensa rara")
		"pink": print("→ Recompensa épica")
		"red": print("🔥 Recompensa legendaria")
		"gold": print("💎💛 Recompensa ULTRA 💛💎")
