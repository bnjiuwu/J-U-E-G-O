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

#== vars ===
var is_facing_right = true
var is_facing_up = false
var is_jumping = false


var facing_direction: Vector2 = Vector2.RIGHT

#==== health ======
@export var max_health: int = 100
var health: int
@onready var health_bar: TextureProgressBar = $HealthBar

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


func _update_health_bar():
	if not health_bar:
		return
	health_bar.max_value = max_health
	health_bar.value = health
	# PARA VER LA BARRA SIEMPRE:
	health_bar.visible = true

func _ready() -> void:
	health = max_health
	add_to_group("player")
	print("Player HP ready:",health)
	_update_health_bar()
	

func _process(_delta):
	if shoot_timer > 0:
		skill_timer -= _delta
		shoot_timer -= _delta
	if Input.is_action_pressed("attack") and shoot_timer <= 0:
		fire_bullet()
		shoot_timer = shoot_delay * fire_rate_mult

		
	if Input.is_action_pressed("skill") and shoot_timer <= 0:
		activate_skill()
		shoot_timer = skill_delay * fire_rate_mult

			

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

	#print("🔫 Bullet fired in direction:", dir)

func activate_skill():
	var basic_skill = big_bullet_scene.instantiate()
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
	pass


#=== dash =====
func dash(delta):
	if not dash_enable:
		return
	# Si ya está en cooldown, lo contamos
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	# Iniciar dash
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0 and not is_dashing:
		is_dashing = true
		dash_timer = dash_time
		dash_cooldown_timer = dash_cooldown

	# Mientras dura el dash
	if is_dashing:
		print("dash")
		dash_timer -= delta
		var dir = Vector2.RIGHT if is_facing_right else Vector2.LEFT
		velocity = dir * dash_speed
		# terminar dash
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
		
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	await animated_sprite.animation_finished
	died.emit()


func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("world colition"):
		modulate = Color(1.0, 0.0, 0.0, 1.0)
		die()
	pass # Replace with function body.

#======== metodos de buff y debuff ===========
func set_dash_enabled(value: bool) -> void:
	dash_enable = value

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
