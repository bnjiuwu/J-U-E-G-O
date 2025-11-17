extends EnemyFlying
class_name PrimalAspid

@export var patrol_range: float = 150.0
@export var attack_range: float = 250.0
@export var retreat_speed: float = 100.0
@export var attack_spread_deg: float = 25.0
@export var projectile_scene: PackedScene
@export var attack_cooldown: float = 2.0

var start_pos: Vector2
var player_target: Node2D = null
var in_combat: bool = false

@onready var spawn_point: Node2D = $ShootSpawnPoint
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer

func _ready():
	super._ready()

	start_pos = global_position

	detection_area.body_entered.connect(_on_detect_enter)
	detection_area.body_exited.connect(_on_detect_exit)

	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_timeout)
	attack_timer.start()


# ============================================================
# FLYING LOGIC
# ============================================================
func flying_behavior(delta: float) -> void:
	# hover vertical ya viene de EnemyFlying
	super.flying_behavior(delta)

	if in_combat and player_target:
		combat_logic(delta)
	else:
		patrol_logic()

	_update_facing()


# ============================================================
# PATROL
# ============================================================
func patrol_logic():
	velocity.x = move_speed * direction

	if abs(global_position.x - start_pos.x) > patrol_range:
		direction *= -1

	is_attacking = false
	is_moving = true


# ============================================================
# COMBAT
# ============================================================
func combat_logic(delta):
	var to_player := player_target.global_position - global_position
	var dist := to_player.length()

	if dist > attack_range + 50:
		velocity.x = move_speed * sign(to_player.x)
	elif dist < attack_range - 50:
		velocity.x = -retreat_speed * sign(to_player.x)
	else:
		velocity.x = 0

	is_moving = abs(velocity.x) > 0.1


func _update_facing():
	if abs(velocity.x) > 0.1:
		sprite.flip_h = velocity.x < 0


# ============================================================
# ATTACK
# ============================================================
func _on_attack_timeout():
	if in_combat and player_target:
		attack()


func attack():
	if not projectile_scene or not player_target:
		return

	var base_dir := (player_target.global_position - spawn_point.global_position).normalized()

	for angle in [-attack_spread_deg, 0, attack_spread_deg]:
		var proj = projectile_scene.instantiate()
		proj.global_position = spawn_point.global_position
		proj.set_direction(base_dir.rotated(deg_to_rad(angle)))
		get_tree().current_scene.add_child(proj)


# ============================================================
# DETECTION
# ============================================================
func _on_detect_enter(body):
	if body.is_in_group("player"):
		player_target = body
		in_combat = true


func _on_detect_exit(body):
	if body == player_target:
		player_target = null
		in_combat = false
