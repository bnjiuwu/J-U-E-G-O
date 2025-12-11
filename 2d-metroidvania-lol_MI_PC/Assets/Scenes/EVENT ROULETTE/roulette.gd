extends Node2D

const SLOT_W: float = 255.0
const GAP: float = 2.0
const SLOT_STEP: float = SLOT_W + GAP
const VIEW_CENTER := Vector2(480, 240)

@export var items_to_generate: int = 100

var blue_range := range(1, 61)
var purple_range := range(61, 85)
var pink_range := range(85, 95)
var red_range := range(95, 99)
var special_range := range(99, 100)

@export var blue_items: Array[PackedScene]
@export var purple_items: Array[PackedScene]
@export var red_items: Array[PackedScene]
@export var special_items: Array[PackedScene]

var item_list: Dictionary = {}
var texture_rects: Array[Sprite2D] = []

var speed: float = 40.0
var increase_value: float = 0.0
var high_limit: float = 270.0
var index_number: int = 2
var case_stopped: bool = false

@onready var scroll: Node2D = $Scroll
@onready var slots: Node2D = $Scroll/Slots
@onready var indicator: Sprite2D = $Indicator

# Ruta nueva y correcta del Panel (lo crearás tú abajo)
@onready var panel: Control = $ResultPanel
@onready var rainbow_panel: CanvasItem = $RainbowPanel
@onready var spin_sfx: AudioStreamPlayer = $SpinSfx if has_node("SpinSfx") else null
@onready var result_sfx: AudioStreamPlayer = $ResultSfx if has_node("ResultSfx") else null

@export var rainbow_speed: float = 0.8  # velocidad del arcoiris
var rainbow_t: float = 0.0

@export var start_speed: float = 40.0
@export var decel: float = 12.0  # mientras más bajo, más largo el spin
@export var result_sfx_offset: float = 0.0  # segundo dentro del audio para arrancar el golpe final
@export var use_result_sfx: bool = false

var item_nodes: Array[CaseItem] = []

@export var player: Node

func start_spin():
	visible = true
	case_stopped = false
	speed = start_speed
	increase_value = 0
	index_number = 2
	high_limit = SLOT_STEP * float(index_number + 1)

	var center_x = get_local_view_center().x
	scroll.position = Vector2.ZERO
	indicator.position.x = center_x

	panel.visible = false
	indicator.visible = true
	
	# --- RAINBOW ON ---
	rainbow_t = 0.0
	if rainbow_panel:
		rainbow_panel.visible = true
	_play_spin_sfx()
	GlobalsSignals.background_music_pause_requested.emit()

func _ready() -> void:
	indicator.position = get_local_view_center()
	scroll.position = Vector2.ZERO  # importante


	item_list = {
		"blue_items": blue_items,
		"purple_items": purple_items,
		"red_items": red_items,
		"special_items": special_items
	}

	_generate_items()

	high_limit = SLOT_STEP * float(index_number + 1)
	
func get_local_view_center() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return vp * 0.5


func _process(delta):
	if case_stopped:
		return
	
		# --- RAINBOW UPDATE ---
	if rainbow_panel:
		rainbow_t += delta * rainbow_speed
		var h := fmod(rainbow_t, 1.0)
		rainbow_panel.modulate = Color.from_hsv(h, 1.0, 1.0, 1.0)
	
	increase_value += speed
	scroll.position.x = -increase_value

	if increase_value > high_limit:
		index_number += 1
		high_limit += SLOT_STEP

	if speed > 0:
		speed = max(0.0, speed - decel * delta)
	else:
		case_stopped = true
		_show_result()


func _generate_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var x: float = viewport_size.x / 2.0

	for i in range(items_to_generate):
		var chance := rng.randi_range(1, 100)
		var key: String

		if chance in blue_range:
			key = "blue_items"
		elif chance in purple_range:
			key = "purple_items"
		elif chance in red_range:
			key = "red_items"
		else:
			key = "special_items"

		var tex_list: Array[PackedScene] = item_list[key]
		if tex_list.is_empty():
			continue

		var picked: PackedScene = tex_list[rng.randi_range(0, tex_list.size() - 1)]

		# Instanciar la escena
		var item_node := picked.instantiate() as Node2D
		item_node.name = key
		item_node.position = Vector2(x + SLOT_W * 0.5, VIEW_CENTER.y)
		slots.add_child(item_node)

		var case_item := item_node as CaseItem
		if case_item:
			item_nodes.append(case_item)

			# si quieres mantener tu lógica visual anterior:
			var sprite := _get_item_sprite(item_node)
			if sprite:
				texture_rects.append(sprite)
		else:
			push_warning("El item no hereda de CaseItem.")
		x += SLOT_STEP

func _show_result():
	if index_number < 0 or index_number >= item_nodes.size():
		push_warning("index_number fuera de rango.")
		return

	var winner_item: CaseItem = item_nodes[index_number]
	_stop_spin_sfx()
	_play_result_sfx()

	# Mostrar imagen en panel
	var winner_sprite := _get_item_sprite(winner_item)
	if winner_sprite:
		panel.get_node("TextureRect").texture = winner_sprite.texture

	panel.visible = true
	indicator.visible = false
		# --- RAINBOW OFF ---
	if rainbow_panel:
		rainbow_panel.visible = false

	# Aplicar efecto temporal al jugador
	if player and winner_item:
		winner_item.apply_to(player)


func _on_CloseButton_pressed() -> void:
	_stop_spin_sfx()
	if result_sfx and result_sfx.playing:
		result_sfx.stop()
	GlobalsSignals.background_music_resume_requested.emit()
	queue_free()
	
func _get_item_sprite(node: Node) -> Sprite2D:
	if node is Sprite2D:
		return node

	var by_name := node.get_node_or_null("Sprite2D")
	if by_name and by_name is Sprite2D:
		return by_name

	for child in node.get_children():
		if child is Sprite2D:
			return child

	return null

func _play_spin_sfx() -> void:
	if spin_sfx == null:
		return
	spin_sfx.stop()
	spin_sfx.play()

func _stop_spin_sfx() -> void:
	if spin_sfx and spin_sfx.playing:
		spin_sfx.stop()

func _play_result_sfx() -> void:
	if not use_result_sfx or result_sfx == null:
		return
	result_sfx.stop()
	var offset: float = max(result_sfx_offset, 0.0)
	result_sfx.play(offset)
