extends CanvasLayer

@onready var sub_viewport_container: SubViewportContainer = $UI/MarginContainer/SubViewportContainer
@onready var sub_viewport: SubViewport = $UI/MarginContainer/SubViewportContainer/SubViewport
@onready var minimap_camera: Camera2D = $"UI/MarginContainer/SubViewportContainer/SubViewport/Minimap Camera"
@onready var player_marker: ColorRect = $UI/MarginContainer/SubViewportContainer/SubViewport/PlayerMarker

var player_node: Node2D

func _ready() -> void:
	# 1. BUSCAR AL JUGADOR
	# Como el player se instancia dinámicamente o está en un grupo, lo buscamos así:
	player_node = get_tree().get_first_node_in_group("player")
	
	if player_node == null:
		push_warning("⚠️ Minimapa: No se encontró al nodo 'player'.")
		# Opcional: esperar un frame si el player tarda en aparecer
		await get_tree().process_frame
		player_node = get_tree().get_first_node_in_group("player")

	# 2. BUSCAR LOS TILEMAPS (Sin usar 'owner')
	# Asumimos que este CanvasLayer es hijo directo del Nivel.
	# Si la estructura es Nivel -> CanvasLayer(Minimapa), usamos get_parent()
	var level_root = get_parent() 
	
	# Buscamos el nodo contenedor de mapas. Asegúrate que en tu escena de Nivel
	# el nodo se llame EXACTAMENTE "TileMaps".
	var tilemaps_container = level_root.get_node_or_null("TileMaps")
	
	if tilemaps_container:
		for tilemap in tilemaps_container.get_children():
			# Verificamos que sea un TileMap o TileMapLayer (Godot 4.3+)
			if tilemap is TileMap or tilemap.is_class("TileMapLayer"):
				var minimap_tilemap = tilemap.duplicate()
				_setup_minimap(minimap_tilemap)
				
				# 3. CONFIGURAR LÍMITES (Esto faltaba llamarse)
				if tilemap.has_method("get_used_rect"):
					var used_rect: Rect2i = tilemap.get_used_rect()
					_set_minimap_limits(used_rect)
	else:
		push_warning("⚠️ Minimapa: No se encontró el nodo 'TileMaps' en el padre: " + str(level_root.name))


func _process(delta: float) -> void:
	# Solo actualizamos si encontramos al jugador
	if player_node:
		minimap_camera.global_position = lerp(
			minimap_camera.global_position,
			player_node.global_position,
			0.2 # Puedes ajustar la velocidad de suavizado
		)
		player_marker.global_position = player_node.global_position


func _setup_minimap(minimap_tilemap: Node2D) -> void:
	sub_viewport.add_child(minimap_tilemap)
	# Opcional: Si quieres que el tilemap del minimapa sea más simple, 
	# aquí podrías cambiarle el color o el material.


func _set_minimap_limits(used_rect: Rect2i) -> void:
	# Multiplicamos por el tamaño del tile (asumo 16x16 por tu código original)
	var tile_size = 16 
	
	minimap_camera.limit_left = used_rect.position.x * tile_size
	minimap_camera.limit_top = used_rect.position.y * tile_size
	minimap_camera.limit_right = (used_rect.position.x + used_rect.size.x) * tile_size
	minimap_camera.limit_bottom = (used_rect.position.y + used_rect.size.y) * tile_size
