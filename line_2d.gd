extends  Line2D
@export var flash_duration: float = 0.15


func _ready() -> void:
	width = 6.0
	default_color = Color(1, 1, 1, 1)

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, flash_duration)
	tween.tween_callback(queue_free)


func setup(point_a: Vector2, point_b: Vector2) -> void:
	clear_points()
	add_point(point_a)
	add_point(point_b)
