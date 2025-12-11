extends CanvasLayer
@onready var sub_viewport_container: SubViewportContainer = $UI/MarginContainer/SubViewportContainer
@onready var sub_viewport: SubViewport = $UI/MarginContainer/SubViewportContainer/SubViewport
@onready var minimap_camera: Camera2D = $"UI/MarginContainer/SubViewportContainer/SubViewport/Minimap Camera"
@onready var player_marker: ColorRect = $UI/MarginContainer/SubViewportContainer/SubViewport/PlayerMarker

@export var tilemaps_root_path: NodePath = NodePath("TileMaps")

var player_node: Node2D

func _ready() -> void:
	var tilemaps := _gather_tilemaps()
	if tilemaps.is_empty():
		push_warning("MiniMap: no se encontraron TileMaps en %s" % owner.name)
		return

	for tilemap in tilemaps:
		var minimap_tilemap = tilemap.duplicate()
		_setup_minimap(minimap_tilemap)
		var used_rect: Rect2i = tilemap.get_used_rect()
		_set_minimap_limits(used_rect)


func _process(delta: float) -> void:
	if player_node:
		minimap_camera.global_position = lerp(
			minimap_camera.global_position,
			player_node.global_position,0.2
		)
		player_marker.global_position = player_node.global_position
	pass

func _gather_tilemaps() -> Array:
	var owner_node := owner
	if owner_node == null:
		return []
	if tilemaps_root_path != NodePath("") and owner_node.has_node(tilemaps_root_path):
		var root_node = owner_node.get_node(tilemaps_root_path)
		return _filter_tilemaps(root_node.get_children())
	return _filter_tilemaps(owner_node.find_children("", "TileMap", true, false))

func _filter_tilemaps(nodes: Array) -> Array:
	var result: Array = []
	for node in nodes:
		if node is TileMap:
			result.append(node)
	return result

func _setup_minimap(minimap_tilemap: TileMap) -> void:
	sub_viewport.add_child(minimap_tilemap)
	
	pass

	
func _set_minimap_limits(used_rect:Rect2i) -> void:
	minimap_camera.limit_left = used_rect.position.x * 1
	minimap_camera.limit_top = used_rect.position.y * 16
	minimap_camera.limit_right = (used_rect.position.x + used_rect.size.x) * 16
	minimap_camera.limit_bottom = (used_rect.position.y + used_rect.size.y) * 16
	
	pass
	
	
	
	
	
	
	
	
	
	
	
	
	
