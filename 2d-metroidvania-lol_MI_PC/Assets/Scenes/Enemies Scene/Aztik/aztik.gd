extends EnemyGround
class_name Aztik

@export_group("Aztik Settings")
@export var patrol_speed: float = 55.0
@export var attack_windup: float = 0.45
@export var attack_cooldown: float = 1.4
@export var missile_speed: float = 360.0
@export var missile_damage: int = 18
@export var missile_scene: PackedScene = preload("res://Assets/Scenes/Enemies Scene/Aztik/AztikMissile.tscn")
@export var my_max_health: int = 110

@onready var floor_detector: RayCast2D = get_node_or_null("FloorDetector")
@onready var wall_detector: RayCast2D = get_node_or_null("WallDetector")
@onready var detection_zone: Area2D = get_node_or_null("DetectionZone")
@onready var missile_spawn: Node2D = get_node_or_null("MissileSpawnPoint")
@onready var attack_cooldown_timer: Timer = get_node_or_null("AttackCooldown")

var player_target: Node2D = null
var _is_preparing_attack: bool = false
var _can_attack: bool = true

func _ready() -> void:
    max_health = my_max_health
    super._ready()

    if floor_detector:
        floor_detector.enabled = true
    if wall_detector:
        wall_detector.enabled = true

    if attack_cooldown_timer:
        attack_cooldown_timer.one_shot = true
        attack_cooldown_timer.wait_time = attack_cooldown
        if not attack_cooldown_timer.timeout.is_connected(_on_attack_cooldown_ready):
            attack_cooldown_timer.timeout.connect(_on_attack_cooldown_ready)

    if detection_zone:
        if not detection_zone.body_entered.is_connected(_on_detection_enter):
            detection_zone.body_entered.connect(_on_detection_enter)
        if not detection_zone.body_exited.is_connected(_on_detection_exit):
            detection_zone.body_exited.connect(_on_detection_exit)

func ground_behavior(_delta: float) -> void:
    if _is_preparing_attack:
        velocity.x = 0
        return

    if player_target:
        _engage_target()
    else:
        _patrol()

func _patrol() -> void:
    velocity.x = direction * patrol_speed

    if wall_detector and wall_detector.is_colliding():
        flip_direction()
    elif floor_detector and is_on_floor() and not floor_detector.is_colliding():
        flip_direction()

    is_attacking = false

func _engage_target() -> void:
    if player_target and not is_instance_valid(player_target):
        player_target = null
        return

    velocity.x = 0
    if player_target:
        _face_position(player_target.global_position)

    if _can_attack and not _is_preparing_attack:
        _start_attack()

func _start_attack() -> void:
    if not missile_scene or not missile_spawn:
        return

    _is_preparing_attack = true
    _can_attack = false
    is_attacking = true
    velocity.x = 0

    var timer := get_tree().create_timer(max(attack_windup, 0.05))
    await timer.timeout

    if is_dead:
        return

    _fire_missile()

    is_attacking = false
    _is_preparing_attack = false

    if attack_cooldown_timer:
        attack_cooldown_timer.start()
    else:
        _can_attack = true

func _fire_missile() -> void:
    var missile = missile_scene.instantiate()
    missile.global_position = missile_spawn.global_position

    _set_property_if_exists(missile, "damage", missile_damage)
    _set_property_if_exists(missile, "speed", missile_speed)

    var aim = Vector2(direction, 0)
    if player_target:
        aim = (player_target.global_position - missile_spawn.global_position).normalized()

    if missile.has_method("set_direction"):
        missile.set_direction(aim)
    else:
        missile.direction = aim

    var parent := get_tree().current_scene
    if parent:
        parent.add_child(missile)

func _on_attack_cooldown_ready() -> void:
    _can_attack = true

func _on_detection_enter(body: Node) -> void:
    if body.is_in_group("player"):
        player_target = body

func _on_detection_exit(body: Node) -> void:
    if body == player_target:
        player_target = null
        is_attacking = false

func _face_position(target_position: Vector2) -> void:
    var delta := target_position.x - global_position.x
    if abs(delta) < 0.01:
        return
    var desired := 1 if delta > 0 else -1
    if desired != direction:
        flip_direction()

func flip_direction() -> void:
    var prev_direction := direction
    super.flip_direction()

    if detection_zone:
        detection_zone.position.x *= -1
        var shape := detection_zone.get_node_or_null("CollisionShape2D")
        if shape:
            shape.position.x *= -1

    if missile_spawn:
        missile_spawn.position.x *= -1

    if prev_direction == direction:
        return

func _set_property_if_exists(target: Object, property_name: String, value) -> void:
    if target == null:
        return
    for info in target.get_property_list():
        if info.has("name") and info["name"] == property_name:
            target.set(property_name, value)
            return
