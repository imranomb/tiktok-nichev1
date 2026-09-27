extends Node2D

@onready var label: Label = $Label

@export var float_distance: float = 60.0
@export var duration: float = 0.8


func setup(amount: int) -> void:
	label.text = str(amount)


func _ready() -> void:
	z_index = 100
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "position:y", position.y - float_distance, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)

	tween.chain().tween_callback(queue_free)
