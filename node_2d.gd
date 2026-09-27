extends CanvasLayer


@export var players: Array[RigidBody2D];
var alive_players: Array = []

@onready var winner_panel: ColorRect = $CanvasLayer/Winner       # prilagodi tip ako Winner nije Node2D
@onready var winner_text: Label = $CanvasLayer/Winner/winner_text  # prilagodi tip (Label/RichTextLabel)
@onready var countdown_label: Label = $Label
@export var tik_sound: AudioStream;
@onready var player_1_timer: Timer = $player/Timer
@onready var player_2_timer: Timer = $player2/Timer
@onready var pickup_scenes: Array[PackedScene] = [preload("res://pickups/super_punch.tscn"), preload("res://pickups/pickup.tscn"), preload("res://pickups/iceman.tscn"), preload("res://pickups/boost.tscn"), preload("res://pickups/doubletrouble.tscn")]
@export var arena_min: Vector2 = Vector2(721, 270)  # malo manje od stvarnih zidova
@export var arena_max: Vector2 = Vector2(1587, 1136)
var pickup_spawn_timer: Timer
func _ready() -> void:
	
	alive_players = players.duplicate()

	for player in players:
		player.player_defeated.connect(_on_player_defeated)
	winner_panel.visible = false

	get_tree().paused = true		
	_setup_pickup_spawner()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("PAUSE"):
		get_tree().paused = not get_tree().paused
		for player in players:
			player.get_node("Timer").start()
		_start_countdown()
func _on_player_defeated(loser: Node, winner_name: String) -> void:
	alive_players.erase(loser)

	if alive_players.size() <= 1:
		get_tree().paused = true
		winner_text.text = winner_name + " wins"
		winner_panel.visible = true

func _start_countdown() -> void:
	countdown_label.visible = true
	var player = AudioStreamPlayer.new()
	player.stream = tik_sound
	add_child(player)
	
	
	countdown_label.text = "3"
	player.play()
	await get_tree().create_timer(1.0).timeout

	countdown_label.text = "2"
	player.play()
	await get_tree().create_timer(1.0).timeout

	countdown_label.text = "1"
	player.play()
	await get_tree().create_timer(1.0).timeout

	countdown_label.text = "FIGHT!"
	await get_tree().create_timer(0.5).timeout

	countdown_label.visible = false
	player.queue_free() 


func _setup_pickup_spawner() -> void:
	pickup_spawn_timer = Timer.new()
	add_child(pickup_spawn_timer)
	pickup_spawn_timer.one_shot = true
	pickup_spawn_timer.timeout.connect(_on_pickup_spawn_timeout)
	_schedule_next_pickup()


func _schedule_next_pickup() -> void:
	var wait_time = randf_range(7.0, 13.0)
	pickup_spawn_timer.wait_time = wait_time
	pickup_spawn_timer.start()


func _on_pickup_spawn_timeout() -> void:
	_spawn_pickup()
	_schedule_next_pickup()   # zakaži sljedeći spawn odmah nakon ovog


func _spawn_pickup() -> void:
	if pickup_scenes.is_empty():
		return

	var random_scene: PackedScene = pickup_scenes.pick_random()   # nasumično bira jednu scenu iz niza
	var pickup_instance = random_scene.instantiate()
	add_child(pickup_instance)

	var random_x = randf_range(arena_min.x, arena_max.x)
	var random_y = randf_range(arena_min.y, arena_max.y)
	pickup_instance.global_position = Vector2(random_x, random_y)
