extends Node2D

const SLOT_W: float = 225.0
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


func start_spin():
	visible = true
	case_stopped = false
	speed = 40
	increase_value = 0
	index_number = 2

	# centro en la cámara actual
	var center_x = get_local_view_center().x
	scroll.position.x = center_x - (SLOT_W / 2)


	indicator.position.x = center_x
	scroll.position = Vector2(0, 0)

	panel.visible = false
	indicator.visible = true
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

	increase_value += speed
	scroll.position.x = -increase_value

	if increase_value > high_limit:
		index_number += 1
		high_limit += SLOT_STEP

	if speed > 0:
		speed -= 0.5
	else:
		speed = 0
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
		elif chance in pink_range:
			key = "pink_items"
		elif chance in red_range:
			key = "red_items"
		else:
			key = "special_items"

		var tex_list: Array[Texture2D] = item_list[key]
		var picked: Texture2D = tex_list[randi() % tex_list.size()]

		var sprite := Sprite2D.new()
		sprite.texture = picked
		sprite.name = key
		sprite.position = Vector2(x + SLOT_W * 0.5, VIEW_CENTER.y)
		slots.add_child(sprite)

		texture_rects.append(sprite)
		x += SLOT_STEP

func _show_result():
	var winner: Sprite2D = texture_rects[index_number]
	panel.get_node("TextureRect").texture = winner.texture
	panel.visible = true

	indicator.visible = false
	

func _on_CloseButton_pressed() -> void:
	queue_free()
