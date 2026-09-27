extends Line2D

@onready var trail: Line2D = self
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	trail.top_level = true

	var trail_gradient = Gradient.new()
	trail_gradient.add_point(0.0, Color(2.046, 1.632, 0.0, 1.0))   # rep - providno, ali overbright
	trail_gradient.add_point(1.0, Color(0.0, 1.264, 2.046, 1.0))   # kod lopte - jako overbright
	trail.gradient = trail_gradient

	var width_curve = Curve.new()
	width_curve.add_point(Vector2(0.0, 0.0))
	width_curve.add_point(Vector2(1.0, 1.0))
	trail.width_curve = width_curve


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
