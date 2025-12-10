extends CharacterBody2D

signal died
var dead: bool = false

@export var material_personaje_rojo: ShaderMaterial

#=== dash properties ==== 
@export var dash_speed: float = 500
@export var dash_time: float = 0.3
@export var dash_cooldown: float = 0.7
  
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_enable: bool = true

#===== jump ===
var jump_count = 0
var max_jumps = 2
var double_jump_enable: bool = true
#==== coyote jump ===== 
var coyote_time := 0.20
var coyote_timer := 0.0
var jump_buffer_time := 0.12
var jump_buffer_timer := 0.0
var has_left_ground := false

#===== movement =====
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@export var move_speed: float = 150
@export var jump_speed: float = 450
@export var jump_pad_height: float = jump_speed * 2
var move_speed_bonus: float = 0.0  # puede ser negativo


#=== sprites ====
@onready var animated_sprite:AnimatedSprite2D = $AnimatedSprite2D
@onready var peo_effect: AnimatedSprite2D = $PEO
@onready var _jump_sfx: AudioStreamPlayer2D = $Audio/JumpSfx if has_node("Audio/JumpSfx") else null
@onready var _dash_sfx: AudioStreamPlayer2D = $Audio/DashSfx if has_node("Audio/DashSfx") else null
@onready var _shoot_sfx: AudioStreamPlayer2D = $Audio/ShootSfx if has_node("Audio/ShootSfx") else null
@onready var _skill_sfx: AudioStreamPlayer2D = $Audio/SkillSfx if has_node("Audio/SkillSfx") else null
@onready var _hurt_sfx: AudioStreamPlayer2D = $Audio/HurtSfx if has_node("Audio/HurtSfx") else null
@onready var _death_sfx: AudioStreamPlayer2D = $Audio/DeathSfx if has_node("Audio/DeathSfx") else null

#== vars ===
var is_facing_right = true
var is_facing_up = false
var is_jumping = false


var facing_direction: Vector2 = Vector2.RIGHT

#==== health ======
@export var max_health: int = 100
var health: int
@onready var health_bar: TextureProgressBar = $CanvasLayer/HealthBar

#============== bullet ===========
@export var bullet_scene: PackedScene
@export var big_bullet_scene: PackedScene
@onready var canon = $muzzle

@export var shoot_delay := 0.2
var shoot_timer := 0.0

@export var skill_delay := 1.5
var skill_timer:= 0.0

var fire_rate_mult: float = 1.0  # 1.0 normal, 0.7 más rápido, 1.3 más lento

var projectile_damage_bonus: int = 0
var projectile_instakill: bool = false


#==== joystick =======
@onready var joystick := get_node_or_null("/root/level_1/Control/touch_controls/Joystick")

#==== damage knockback =======
@export var invulnerability_time: float = 1.0

@export var knockback_force: Vector2 = Vector2(-300, -200) # (x: fuerza lateral, y: salto)
var is_knockback: bool = false
var knockback_timer: float = 0.0
var knockback_duration: float = 0.2 # cuánto dura el retroceso
var is_invulnerable: bool = false


# ====== ATTACK METER ======
@export var attack_meter_max: float = 100.0
@export var meter_gain_per_damage: float = 1.0
@export var meter_skill_mult: float = 1.5
@export var meter_gain_cap_per_hit: float = 40.0  # evita llenar infinito con instakill
@export var attack_damage_to_send: int = 5  # daño que mandarás al rival

var attack_meter: float = 0.0
var _auto_attack_lock := false

@onready var attack_layer: CanvasLayer = $CanvasLayer
@onready var attack_bar: Range = $CanvasLayer/AttackBar

# ======= EFFECT UI =======
var active_effects: Dictionary = {}  # effect_name -> end_time_sec
var effect_label: Label = null

func _match_active() -> bool:
	return Network and str(Network.matchId) != ""

func _update_attack_bar() -> void:
	if attack_bar == null:
		return

	if not _match_active():
		attack_bar.visible = false
		return

	attack_bar.max_value = attack_meter_max
	attack_bar.value = attack_meter
	attack_bar.visible = true


func _gain_attack_meter(dmg: int, is_skill: bool) -> void:
	# Si no hay match activo, no acumules ni muestres
	if not _match_active():
		return

	var gain := float(dmg) * meter_gain_per_damage
	if is_skill:
		gain *= meter_skill_mult

	gain = min(gain, meter_gain_cap_per_hit)

	attack_meter = clamp(attack_meter + gain, 0.0, attack_meter_max)
	_update_attack_bar()

	if attack_meter >= attack_meter_max and not _auto_attack_lock:
		_auto_attack_lock = true
		try_send_attack()
		await get_tree().process_frame
		_auto_attack_lock = false



func _connect_projectile_meter(proj: Node, is_skill: bool) -> void:
	if proj == null:
		return
	# ✅ no depender del type
	if proj.has_signal("hit_enemy"):
		proj.hit_enemy.connect(func(dmg: int):
			_gain_attack_meter(dmg, is_skill)
		, CONNECT_ONE_SHOT)


func try_send_attack() -> void:
	# Solo en match
	if not Network or Network.matchId == "":
		return

	Network.send_game_payload({
		"type": "attack",
		"damage": attack_damage_to_send
	})

	attack_meter = 0.0
	_update_attack_bar()
	print("📤 Ataque enviado al rival (auto)")


func _update_health_bar():
	if not health_bar:
		return
	health_bar.max_value = max_health
	health_bar.value = health
	# PARA VER LA BARRA SIEMPRE:
	health_bar.visible = true

func _ready() -> void:
	add_to_group("player")
	effect_label = get_tree().get_first_node_in_group("effect_ui")
	_update_effect_label()
	health = max_health
	_update_health_bar()
	
	_update_attack_bar()
	call_deferred("_update_attack_bar")

func _process(_delta):
	var delta2 = _delta
	if shoot_timer > 0: 
		shoot_timer -= _delta
	
	if skill_timer > 0:
		skill_timer -= delta2
	if Input.is_action_pressed("attack") and shoot_timer <= 0:
		fire_bullet()
		shoot_timer = shoot_delay * fire_rate_mult

	if Input.is_action_pressed("skill") and skill_timer <= 0:
		activate_skill()
		skill_timer = skill_delay * fire_rate_mult

	_update_attack_bar()
	_update_effect_label()
	if Engine.get_frames_drawn() % 60 == 0:
		print("matchId:", Network.matchId, " | bar visible:", attack_bar.visible)

func register_effect(effect_name: String, duration: float) -> void:
	if duration <= 0:
		return

	var now := Time.get_ticks_msec() / 1000.0
	active_effects[effect_name] = now + duration
	_update_effect_label()


func unregister_effect(effect_name: String) -> void:
	if active_effects.has(effect_name):
		active_effects.erase(effect_name)
	_update_effect_label()


func _update_effect_label() -> void:
	if effect_label == null:
		return

	if active_effects.is_empty():
		effect_label.visible = false
		return

	var now := Time.get_ticks_msec() / 1000.0
	var keys := active_effects.keys()

	var lines: Array[String] = []
	for k in keys:
		var remaining := float(active_effects[k]) - now
		if remaining <= 0.0:
			active_effects.erase(k)
			continue
		lines.append("%s: %ds" % [str(k), int(ceil(remaining))])

	if lines.is_empty():
		effect_label.visible = false
		return

	effect_label.visible = true
	effect_label.text = "\n".join(lines)


func _physics_process(delta):

	# ▶ PRIORIDAD: si está en knockback, se mueve sólo por la fuerza recibida
	if is_knockback:
		# aplicar gravedad mientras está en el aire en knockback
		if not is_on_floor():
			velocity.y += gravity * delta

		move_and_slide()

		knockback_timer -= delta
		if knockback_timer <= 0.0:
			is_knockback = false
		return  # 🔴 importante: no seguir con el movimiento normal


	# ▶ MOVIMIENTO NORMAL (sin knockback)
	if not is_dashing:
		jump(delta)
		move_x()
		
	flip()
	dash(delta)
	update_animation()
	move_and_slide()


#	_check_environment_damage()

func update_animation():
	#--- dash
	if is_dashing:
		peo_effect.flip_h = not is_facing_right

		# Distancia del efecto detrás del jugador
		var offset_x = -25 if is_facing_right else 25  # detrás del jugador
		var offset_y = 4  # leve ajuste vertical
		
		# Posición relativa al jugador
		peo_effect.position = Vector2(offset_x, offset_y)
		
		 # opcional, si quieres que el efecto también se invierta
		if animated_sprite.animation != "dash":
			animated_sprite.play("dash")
			
			peo_effect.visible = true
			peo_effect.play("peo")
			peo_effect.frame = 0
			
			
		return
		
	if not is_dashing and peo_effect.visible:
		peo_effect.visible = false
		
	if not is_on_floor():
		if velocity.y < 0:
			if Input.is_action_pressed("look_up"):
				animated_sprite.play("jump_looking_up")
			else:
				animated_sprite.play("jump")
				
			pass
		else:
			if Input.is_action_pressed("look_up"):
				animated_sprite.play("fall_lookin_up")
			else:
				animated_sprite.play("fall")
				
			pass
		return
		
	if velocity.x:
		if Input.is_action_pressed("look_up"):
			animated_sprite.play("up_shoot_walk") 
			
		else:
			animated_sprite.play("walk")
	else:
		if Input.is_action_pressed("look_up"):
			animated_sprite.play("up_idle")
			
		else:
			animated_sprite.play("idle")
			

#==== movement ====
func jump(delta: float) -> void:
	# =========================
	#  UPDATE COYOTE TIMER
	# =========================
	if is_on_floor():
		coyote_timer = coyote_time
		has_left_ground = false
	else:
		coyote_timer = max(0, coyote_timer - delta)

	# =========================
	#  UPDATE JUMP BUFFER
	# =========================
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(0, jump_buffer_timer - delta)

	var wants_to_jump := jump_buffer_timer > 0


	# =========================
	#  NORMAL OR COYOTE JUMP
	# =========================
	if wants_to_jump and (is_on_floor() or coyote_timer > 0):
		velocity.y = -jump_speed
		jump_count = 1                    # 1st jump used
		has_left_ground = true           # airborn
		coyote_timer = 0                 # consume coyote
		jump_buffer_timer = 0
		_play_sfx(_jump_sfx)
		return


	# =========================
	#  DOUBLE JUMP
	# =========================
	# IMPORTANT:
	# must be airborne AND after the first real jump
	# NOT during coyote
	if wants_to_jump \
	and double_jump_enable \
	and not is_on_floor() \
	and coyote_timer <= 0 \
	and jump_count < max_jumps:


		velocity.y = -jump_speed
		jump_count += 1
		has_left_ground = true
		jump_buffer_timer = 0
		_play_sfx(_jump_sfx)
		print("DOUBLE JUMP")
		return


	# =========================
	# VARIABLE JUMP HEIGHT
	# =========================
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

	# =========================
	# APPLY GRAVITY
	# =========================
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		jump_count = 0

		
		
func flip():
	if velocity.x > 0:
		is_facing_right = true
		animated_sprite.flip_h = false
	elif velocity.x < 0 :
		is_facing_right = false
		animated_sprite.flip_h = true	
func move_x():
	var input_axis = Input.get_axis("move_left","move_right")
	velocity.x = input_axis * (move_speed + move_speed_bonus)
	
#==== fire bullet ===
func fire_bullet():
	var bullet = bullet_scene.instantiate()
	# ✅ conectar barra
	_connect_projectile_meter(bullet, false)
	var dir = Vector2.ZERO
# simple y efectivo

	# Obtener vector del joystick
	if joystick and joystick.pressing:
		var joy = joystick.posVector
		if joy.length() > 0.1:  # margen de error
			dir = joy.normalized()
		else:
			dir = Vector2.RIGHT if is_facing_right else Vector2.LEFT
	else:
		# fallback a input teclado
		var is_looking_up = Input.is_action_pressed("look_up")
		var moving_horizontally = Input.is_action_pressed("move_right") or Input.is_action_pressed("move_left")
		
		if is_looking_up:
			if moving_horizontally:
				if is_facing_right:
					dir = Vector2.from_angle(deg_to_rad(-45))
				else:
					dir = Vector2.from_angle(deg_to_rad(-135))
			else:
				dir = Vector2.UP
		elif is_facing_right:
			dir = Vector2.RIGHT
		else:
			dir = Vector2.LEFT

	# Configurar muzzle según dirección
	$muzzle.position = dir * 14  # distancia base del muzzle
	$muzzle.rotation = dir.angle()
	
	if bullet is Projectile:
		bullet.damage += projectile_damage_bonus
		if projectile_instakill:
			bullet.damage = 999999
	
	
	# Disparar bala
	bullet.direction = dir
	bullet.global_position = $muzzle.global_position
	bullet.rotation = dir.angle()
	get_tree().current_scene.add_child(bullet)
	_play_sfx(_shoot_sfx)

	#print("🔫 Bullet fired in direction:", dir)

func activate_skill():
	var basic_skill = big_bullet_scene.instantiate()
	_connect_projectile_meter(basic_skill, true)
	var dir = Vector2.ZERO
	
	# Obtener vector del joystick
	if joystick and joystick.pressing:
		var joy = joystick.posVector
		if joy.length() > 0.1:  # margen de error
			dir = joy.normalized()
		else:
			dir = Vector2.RIGHT if is_facing_right else Vector2.LEFT
	else:
		# fallback a input teclado
		var is_looking_up = Input.is_action_pressed("look_up")
		var moving_horizontally = Input.is_action_pressed("move_right") or Input.is_action_pressed("move_left")
		
		if is_looking_up:
			if moving_horizontally:
				if is_facing_right:
					dir = Vector2.from_angle(deg_to_rad(-45))
				else:
					dir = Vector2.from_angle(deg_to_rad(-135))
			else:
				dir = Vector2.UP
		elif is_facing_right:
			dir = Vector2.RIGHT
		else:
			dir = Vector2.LEFT

	# Configurar muzzle según dirección
	$muzzle.position = dir * 14  # distancia base del muzzle
	$muzzle.rotation = dir.angle()
	
	# Disparar bala
	basic_skill.direction = dir
	basic_skill.global_position = $muzzle.global_position
	basic_skill.rotation = dir.angle()
	get_tree().current_scene.add_child(basic_skill)

	print("WEON DISPARO ABILIDAD LOOL:", dir)
	_play_sfx(_skill_sfx)
	pass


#=== dash =====
func dash(delta):
	# ✅ si algo lo deshabilita a mitad de dash
	if not dash_enable:
		_cancel_dash()
		return

	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = dash_time
		dash_cooldown_timer = dash_cooldown
		_play_sfx(_dash_sfx)

	if is_dashing:
		dash_timer -= delta
		var dir = Vector2.RIGHT if is_facing_right else Vector2.LEFT
		velocity = dir * dash_speed

		if dash_timer <= 0:
			is_dashing = false


func _on_hitbox_area_entered(area: Area2D) -> void:
	print("⚠️ Player detectó un área:", area.name)
	
	if area.is_in_group("enemy_hitbox"):
		print("⚡ Player hit by enemy")
		take_damage(20, area.global_position)
	
	elif area.is_in_group("enemy projectile"):
		print("💥 Daño por proyectil")
		take_damage(area.damage, area.global_position)


func take_damage(amount: int, attacker_pos: Vector2 = global_position) -> void:
	if is_invulnerable:
		return
		
	is_invulnerable = true
	
	modulate = Color(1.0, 0.0, 0.0, 1.0)
	
	#--- daño ---
	health -= amount
	_update_health_bar()
	print("⚠️ Player recibió", amount, "daño | HP:", health)
	_play_sfx(_hurt_sfx)
	
	if health < 0:
		health = 0

	if health <= 0:
		die()
		
	var dir = sign(global_position.x - attacker_pos.x)
	velocity = Vector2(knockback_force.x * dir, knockback_force.y * 2)
	is_knockback = true
	knockback_timer = knockback_duration
	
	await get_tree().create_timer(invulnerability_time).timeout
	is_invulnerable = false
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	
func die() -> void:
	if dead: return
	dead = true
	print("💀 Player ha muerto → emitiendo señal")
	velocity = Vector2.ZERO
	set_physics_process(false)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true

	var frames := animated_sprite.sprite_frames
	
	if frames and frames.has_animation("death"):
		animated_sprite.play("death")
		
	_play_sfx(_death_sfx)
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	await animated_sprite.animation_finished
	died.emit()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("world colition"):
		modulate = Color(1.0, 0.0, 0.0, 1.0)
		die()
	pass # Replace with function body.

#======== metodos de buff y debuff ===========
func _cancel_dash() -> void:
	if not is_dashing:
		return

	is_dashing = false
	dash_timer = 0.0
	velocity.x = 0.0  # opcional, evita arrastre raro
	if peo_effect:
		peo_effect.visible = false
		
func set_dash_enabled(value: bool) -> void:
	dash_enable = value

	# ✅ si la ruleta lo desactiva en medio del dash
	if not dash_enable:
		_cancel_dash()

func set_double_jump_enabled(value: bool) -> void:
	double_jump_enable = value

func add_move_speed_bonus(value: float) -> void:
	move_speed_bonus += value

func set_fire_rate_mult(value: float) -> void:
	fire_rate_mult = max(0.1, value)  # evita cosas raras
func add_projectile_damage_bonus(value: int) -> void:
	projectile_damage_bonus += value

func set_projectile_instakill(value: bool) -> void:
	projectile_instakill = value

func increase_max_health(amount: int) -> void:
	max_health += amount
	health += amount
	health = min(health, max_health)
	_update_health_bar()
func _play_sfx(player: AudioStreamPlayer2D) -> void:
	if player == null:
		return
	player.stop()
	player.play()
