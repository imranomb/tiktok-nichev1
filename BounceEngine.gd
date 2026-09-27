extends RigidBody2D

signal player_defeated(loser_name: String)
@export var bounce_impulse_boost: float = 50.0
@export var initial_speed: float = 300.0   # <- brzina kojom lopta kreće
@export var weapon_rotation_speed: float = 0  # radijana po sekundi
@export var weapon_distance: float = 125.0 
@export var playerHealth: int = 1000;
@export var bounce_sound: AudioStream;
@export var attack_sound: AudioStream;
@export var trail_length: int = 20        # koliko tačaka trag pamti
@export var trail_update_interval: float = 0.02
@export var opponent: RigidBody2D;
@export var weapon_clash_sound: AudioStream
var gameStarted = false;
var players = ["Bosnia", "Haalland"]

var damage_multiplier: float = 1.0        # NOVO - koliko štete zadaješ (2.0 = duplo)
var incoming_damage_multiplier: float = 1.0  # NOVO - koliko štete primaš (0.5 = upola manje)
var speed_boost_active: bool = false
var speed_multiplier: float = 1.0 

@onready var weapon_projectile_scene: PackedScene = preload("res://players/zPickups/projectile.tscn")
@onready var weapon: Sprite2D = $Weapon
@onready var trail: Line2D = $Trail
var trail_timer: float = 0.0
@export var weapon_angle: float = 90
var min_speed: float = 0

@onready var weapon_area: Area2D = $Weapon/Area2D
var weapon_hit_cooldown: bool = false

var freeze_end_time: float = 0.0   # NOVO - kada freeze treba da završi (apsolutno vrijeme)
var is_frozen: bool = false

@onready var weapon2: Sprite2D = $Weapon2
@onready var weapon2_area: Area2D = $Weapon2/Area2D

var weapon2_active: bool = false
var weapon2_hit_cooldown: bool = false

var super_punch_active: bool = false
var super_punch_end_time: float = 0.0
@export var knockback_force: float = 4000.0

@onready var damage_number_scene: PackedScene = preload("res://damage_number.tscn")
@export var damage_number_offset: float = 80.0   
@onready var wall_flash_scene: PackedScene = preload("res://wall_scene.tscn")
@onready var blood_particles: GPUParticles2D = $BloodParticles
func _ready() -> void:
	add_to_group("fighters")
	blood_particles.global_position = global_position
	body_shape_entered.connect(_on_body_shape_entered)
	weapon_area.body_entered.connect(_on_weapon_hit)
	weapon_area.area_entered.connect(_on_weapon_hit_area)
	$Timer.one_shot = true;

	weapon2_area.body_entered.connect(_on_weapon2_hit)
	weapon2.visible = false
	weapon2_area.set_deferred("monitoring", false)

func _process(delta: float) -> void:
	opponent = _get_nearest_opponent()
	weapon_angle += weapon_rotation_speed * delta
	weapon.position = Vector2(cos(weapon_angle), sin(weapon_angle)) * weapon_distance
	weapon.rotation = weapon_angle + PI
	_update_trail(delta)
	
	if weapon2_active:
		var weapon2_angle = weapon_angle + PI   # suprotna strana (180°)
		weapon2.position = Vector2(cos(weapon2_angle), sin(weapon2_angle)) * weapon_distance
		weapon2.rotation = weapon2_angle + PI

func _launch_ball() -> void:
	# nasumičan pravac (bilo koji ugao 0-360 stepeni)
	var random_angle = randf_range(0, TAU)
	var direction = Vector2(cos(random_angle), sin(random_angle))
	linear_velocity = direction * initial_speed

func _on_body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if gameStarted == false: return;
	if body.is_in_group("walls"):
		_boost_after_bounce()
		#_bounce_toward_opponent()
		_play_bounce_effect()
		_spawn_wall_flash(body, body_shape_index)

func _boost_after_bounce() -> void:
	var current_velocity = linear_velocity
	var random_direction = randf_range(-0.3, 0.3);
	if current_velocity.length() > 0:
		linear_velocity = current_velocity.normalized() * (current_velocity.length() + bounce_impulse_boost)
		linear_velocity = linear_velocity.rotated(random_direction)
		

func _play_bounce_effect() -> void:
	if bounce_sound:
		var player = AudioStreamPlayer2D.new()
		player.stream = bounce_sound
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)


func _physics_process(_delta: float) -> void:
	if freeze:
		return

	var target_speed = min_speed * speed_multiplier
	var current_speed = linear_velocity.length()

	if current_speed > 0 and abs(current_speed - target_speed) > 1.0:
		linear_velocity = linear_velocity.normalized() * target_speed


func _on_timer_timeout() -> void:
	_launch_ball();
	gameStarted = true;
	min_speed = 400;
	weapon_rotation_speed = 5.0;
func _update_trail(delta: float) -> void:
	trail_timer += delta
	if trail_timer < trail_update_interval:
		return
	trail_timer = 0.0

	# offset pozicija - iza lopte, suprotno od smjera kretanja
	var offset_direction = -linear_velocity.normalized()
	var trail_point = global_position + offset_direction * 70

	trail.add_point(trail_point)

	if trail.get_point_count() > trail_length:
		trail.remove_point(0)

func _die() -> void:
	var winner_name = ""
	if opponent:
		winner_name = opponent.get_node("Name").text

	player_defeated.emit(self, winner_name)
	queue_free()
func _bounce_toward_opponent() -> void:
	if not opponent:
		return

	var current_speed = linear_velocity.length()
	var direction_to_opponent = (opponent.global_position - global_position).normalized()

	linear_velocity = direction_to_opponent * current_speed
	
func _on_weapon_hit(body: Node) -> void:
	# provjeri da nije udario svoju loptu ili zid
	if body == self or body.is_in_group("walls") or weapon_hit_cooldown:
		return
	
	var damage = int(80 * damage_multiplier)
	body.take_damage(damage)
	
	if super_punch_active and body.has_method("apply_knockback"):
		body.apply_knockback(global_position, knockback_force)   # NOVO 
	
	_reverse_weapon_rotation()
	_hit_stop()
	
	weapon_hit_cooldown = true;
	await get_tree().create_timer(0.3).timeout
	weapon_hit_cooldown = false
@warning_ignore("unused_parameter")
func _on_weapon_hit_area(area: Area2D) -> void:
	# ako je protivničko oružje takođe Area2D, ovaj signal se okine kad se dvije Area2D dodirnu
	_play_weapon_clash_sound()
	_reverse_weapon_rotation()


func _reverse_weapon_rotation() -> void:
	weapon_rotation_speed = -weapon_rotation_speed

func take_damage(amount: int):
	var actual_damage = int(amount * incoming_damage_multiplier) 
	var player = AudioStreamPlayer2D.new()
	player.stream = attack_sound
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	
	blood_particles.restart()   # NOVO - resetuje i ponovo emituje "burst" čestica
	blood_particles.emitting = true
	
	playerHealth -= actual_damage;
	$ProgressBar.value = playerHealth
	$ProgressBar/helthpoints.text = str(playerHealth)
	
	_flash_red()
	
	_show_damage_number(actual_damage)
	
	if playerHealth <= 0:
		_die();

func fire_weapons(count: int = 5) -> void:
	if not weapon_projectile_scene or not opponent:
		return

	var direction_to_opponent = (opponent.global_position - global_position).normalized()
	var spawn_pos = global_position

	for i in range(count):
		var projectile = weapon_projectile_scene.instantiate()
		projectile.shooter = self
		get_parent().call_deferred("add_child", projectile)
		await get_tree().process_frame

		if not is_instance_valid(projectile):
			continue

		projectile.global_position = spawn_pos

		var spread_angle = randf_range(-0.3, 0.3)
		var spread_direction = direction_to_opponent.rotated(spread_angle)

		projectile.rotation = spread_direction.angle() + PI / 2   # NOVO - rotira sprite u pravcu leta

		projectile.launch(spread_direction)

		await get_tree().create_timer(0.1).timeout

func freeze_opponent(duration: float = 5.0) -> void:
	if not opponent:
		return

	var direction_to_opponent = (opponent.global_position - global_position).normalized()
	var current_speed = linear_velocity.length()
	set_deferred("linear_velocity", direction_to_opponent * current_speed)

	opponent.freeze_self(duration)


func freeze_self(duration: float = 5.0) -> void:
	var new_end_time = Time.get_ticks_msec() / 1000.0 + duration
	freeze_end_time = max(freeze_end_time, new_end_time)   # produži ako je novi duži

	if is_frozen:
		return   # već postoji aktivan freeze loop, on će sam produžiti trajanje

	is_frozen = true
	var saved_velocity = linear_velocity

	set_deferred("freeze", true)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	var old_rotation_speed = weapon_rotation_speed
	weapon_rotation_speed = 0.0
	
	while Time.get_ticks_msec() / 1000.0 < freeze_end_time:
		await get_tree().create_timer(0.1, true, false, true).timeout

	set_deferred("freeze", false)
	linear_velocity = saved_velocity
	weapon_rotation_speed = old_rotation_speed
	is_frozen = false
func activate_boost(duration: float = 10.0) -> void:
	speed_multiplier = 1.5
	damage_multiplier = 2.0
	incoming_damage_multiplier = 0.5

	# NOVO - usmjeri loptu prema protivniku odmah pri aktivaciji boosta
	if opponent:
		var direction_to_opponent = (opponent.global_position - global_position).normalized()
		var current_speed = linear_velocity.length()
		set_deferred("linear_velocity", direction_to_opponent * current_speed)

	await get_tree().create_timer(duration, true, false, true).timeout

	speed_multiplier = 1.0
	damage_multiplier = 1.0
	incoming_damage_multiplier = 1.0

func _flash_red() -> void:
	modulate = Color(1, 0, 0)   # crvena
	await get_tree().create_timer(0.15).timeout
	modulate = Color(1, 1, 1)  

func activate_double_weapon(duration: float = 10.0) -> void:
	weapon2.visible = true
	weapon2_area.set_deferred("monitoring", true)
	weapon2_active = true

	if opponent:
		var direction_to_opponent = (opponent.global_position - global_position).normalized()
		var current_speed = linear_velocity.length()
		set_deferred("linear_velocity", direction_to_opponent * current_speed)

	await get_tree().create_timer(duration, true, false, true).timeout

	weapon2.visible = false
	weapon2_area.set_deferred("monitoring", false)
	weapon2_active = false


func _on_weapon2_hit(body: Node) -> void:
	if body == self or body.is_in_group("walls") or weapon2_hit_cooldown:
		return

	var damage = int(80 * damage_multiplier)
	body.take_damage(damage)
	
	if super_punch_active and body.has_method("apply_knockback"):
		body.apply_knockback(global_position, knockback_force)   # NOVO 
	
	_hit_stop()

	weapon2_hit_cooldown = true
	await get_tree().create_timer(0.3).timeout
	weapon2_hit_cooldown = false

func _get_nearest_opponent() -> RigidBody2D:
	var nearest: RigidBody2D = null
	var nearest_distance: float = INF

	for ball in get_tree().get_nodes_in_group("fighters"):
		if ball == self:
			continue   # preskoči samog sebe

		var distance = global_position.distance_to(ball.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = ball

	return nearest


func activate_super_punch(duration: float = 10.0) -> void:
	var new_end_time = Time.get_ticks_msec() / 1000.0 + duration
	super_punch_end_time = max(super_punch_end_time, new_end_time)

	if super_punch_active:
		return

	super_punch_active = true
	damage_multiplier = 2.5;

	while Time.get_ticks_msec() / 1000.0 < super_punch_end_time:
		await get_tree().create_timer(0.1, true, false, true).timeout

	super_punch_active = false
	damage_multiplier = 1.0


func apply_knockback(from_position: Vector2, force: float) -> void:
	var knockback_direction = (global_position - from_position).normalized()
	set_deferred("linear_velocity", knockback_direction * force)

func _show_damage_number(amount: int) -> void:
	var number = damage_number_scene.instantiate()
	get_parent().call_deferred("add_child", number)
	await get_tree().process_frame

	if is_instance_valid(number):
		number.global_position = global_position + Vector2(randf_range(-20, 20), -damage_number_offset)
		number.setup(amount)

func _play_weapon_clash_sound() -> void:
	if weapon_clash_sound:
		var player = AudioStreamPlayer2D.new()
		player.stream = weapon_clash_sound
		add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
func _hit_stop(duration: float = 0.20, scale: float = 0.15) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func _spawn_wall_flash(wall: Node, shape_index: int) -> void:
	var owner_id = wall.shape_find_owner(shape_index)
	var shape_node = wall.shape_owner_get_owner(owner_id) as CollisionShape2D

	if not shape_node or not shape_node.shape:
		return

	var flash = wall_flash_scene.instantiate()
	get_parent().call_deferred("add_child", flash)
	await get_tree().process_frame

	if not is_instance_valid(flash):
		return

	var rect_shape = shape_node.shape as RectangleShape2D
	if rect_shape:
		var half_size = rect_shape.size / 2.0
		var shape_global_pos = shape_node.global_position
		var shape_rotation = shape_node.global_rotation   # NOVO - uzmi u obzir rotaciju

		# tačke linije u LOKALNOM prostoru shape-a
		var local_point_a: Vector2
		var local_point_b: Vector2

		if rect_shape.size.x > rect_shape.size.y:
			local_point_a = Vector2(-half_size.x, 0)
			local_point_b = Vector2(half_size.x, 0)
		else:
			local_point_a = Vector2(0, -half_size.y)
			local_point_b = Vector2(0, half_size.y)

		# rotiraj tačke prema stvarnoj rotaciji shape-a, pa ih pomjeri na globalnu poziciju
		var point_a = shape_global_pos + local_point_a.rotated(shape_rotation)
		var point_b = shape_global_pos + local_point_b.rotated(shape_rotation)

		flash.setup(point_a, point_b)
