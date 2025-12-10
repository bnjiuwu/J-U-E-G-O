extends EnemyGround
class_name Mage

@export var speed: float = 30.0
@export var attack_range: float = 400.0
@export var fire_rate: float = 1.5
@export var magic_ball_scene: PackedScene
@export var damage: int = 15


@onready var floor_check: RayCast2D = $FloorCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var spawn_point: Node2D = $MagicBallSpawnPoint
@onready var fire_cooldown: Timer = $FireCooldown
@onready var detection_zone: Area2D = $DetectionZone

var player_target: CharacterBody2D = null
var can_fire: bool = true


func _ready():
	super._ready()

	fire_cooldown.one_shot = true
	fire_cooldown.timeout.connect(_on_fire_ready)

	sprite.frame_changed.connect(_on_frame_changed)


# ============================================================
#   LOGICA DE ENEMIGO TERRESTRE (solo IA)
# ============================================================
func ground_behavior(delta: float) -> void:
	if player_target:
		attack_behavior()
	else:
		patrol_behavior()

	_update_directional_nodes()


# ============================================================
#   PATRULLA
# ============================================================
func patrol_behavior() -> void:
	velocity.x = direction * speed

	if wall_check.is_colliding():
		flip_direction()

	if floor_check and is_on_floor() and not floor_check.is_colliding():
		flip_direction()

	is_attacking = false


# ============================================================
#   ATAQUE
# ============================================================
func attack_behavior() -> void:
	var dist := global_position.distance_to(player_target.global_position)

	# mirar al jugador
	direction = 1 if player_target.global_position.x > global_position.x else -1

	# si está lejos → caminar hacia él
	if dist > attack_range:
		velocity.x = direction * speed
		is_attacking = false
		return

	# dentro del rango → detener y atacar
	velocity.x = 0

	if can_fire and not is_attacking:
		is_attacking = true
		can_fire = false
		fire_cooldown.start(fire_rate)

		sprite.play("attack1" if randf() < 0.5 else "attack2")


# ============================================================
#   DISPARAR MAGIA
# ============================================================
func _on_frame_changed() -> void:
	if not is_attacking:
		return

	if sprite.animation in ["attack1", "attack2"] and sprite.frame == 4:
		fire_magic()


func fire_magic() -> void:
	if not magic_ball_scene:
		return

	var b = magic_ball_scene.instantiate()
	b.global_position = spawn_point.global_position

	var dir = (player_target.global_position - global_position).normalized()
	b.set_direction(dir)

	get_tree().current_scene.add_child(b)


func _on_fire_ready():
	can_fire = true


# ============================================================
#   DETECCIÓN
# ============================================================
func _on_detection_zone_body_entered(body: Node):
	if body.is_in_group("player"):
		player_target = body


func _on_detection_zone_body_exited(body: Node):
	if body == player_target:
		player_target = null


# ============================================================
#   RAYCASTS / SPAWNPOINT SEGÚN DIRECCIÓN
# ============================================================
func _update_directional_nodes():
	var s :float= sign(direction)

	if wall_check:
		wall_check.position.x = s * abs(wall_check.position.x)
		wall_check.target_position.x = s * abs(wall_check.target_position.x)

	if floor_check:
		floor_check.position.x = s * abs(floor_check.position.x)
		floor_check.target_position.x = s * abs(floor_check.target_position.x)

	if spawn_point:
		spawn_point.position.x = s * abs(spawn_point.position.x)

	if detection_zone:
		detection_zone.position.x = s * abs(detection_zone.position.x)
		var shape := detection_zone.get_node("CollisionShape2D")
		if shape:
			shape.position.x = s * abs(shape.position.x)
