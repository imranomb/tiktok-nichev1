extends TextureRect

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var area: Area2D = $Area2D

var is_active: bool = false

@onready var pickup_ring_scene: PackedScene = preload("res://pickups/pickup_ring.tscn")
@export var ring_color: Color = Color(0.0, 0.509, 0.307, 1.0) 
@export var ring_duration: float = 10.0

func _ready() -> void:
	animation_player.play("pickup_show")
	area.body_entered.connect(_on_body_entered)

	_set_grayscale(true)
	await get_tree().create_timer(3.0).timeout
	is_active = true
	_set_grayscale(false)


func _on_body_entered(body: Node) -> void:
	if not is_active:
		return

	if body.has_method("activate_boost"):
		body.call_deferred("activate_boost", 5.0)

	_spawn_ring(body)
	call_deferred("queue_free")


func _set_grayscale(enabled: bool) -> void:
	if enabled:
		modulate = Color(0.5, 0.5, 0.5)
	else:
		modulate = Color(1, 1, 1)

func _spawn_ring(target: Node) -> void:
	var ring = pickup_ring_scene.instantiate()
	ring.setup(ring_color, ring_duration)
	target.call_deferred("add_child", ring)   # child LOPTE, ne glavne scene
	await get_tree().process_frame

	if is_instance_valid(ring):
		ring.position = Vector2.ZERO 
