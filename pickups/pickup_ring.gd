extends Node2D

@export var ring_color: Color = Color.WHITE
@export var start_radius: float = 20.0
@export var end_radius: float = 80.0
@export var duration: float = 10
@export var line_width: float = 6.0

var current_radius: float = 0.0
var current_alpha: float = 1.0


func setup(color: Color, custom_duration: float = -1.0) -> void:
	ring_color = color
	current_radius = start_radius

	if custom_duration > 0:
		duration = custom_duration  

func _ready() -> void:
	z_index = 50

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "current_radius", end_radius, duration)
	tween.tween_property(self, "current_alpha", 0.0, duration)
	tween.chain().tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()   # traži ponovno crtanje svaki frame dok se tween izvršava


func _draw() -> void:
	var draw_color = Color(ring_color.r, ring_color.g, ring_color.b, current_alpha)
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 64, draw_color, line_width)
