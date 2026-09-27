extends Area2D


var velocity: Vector2 = Vector2.ZERO
@export var speed: float = 500.0
@export var lifetime: float = 3.0

var shooter: Node = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _process(delta: float) -> void:
	global_position += velocity * delta   # pravolinijsko kretanje, NE kruženje


func launch(direction: Vector2) -> void:
	velocity = direction.normalized() * speed


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body.has_method("take_damage"):
		body.take_damage(100)
	queue_free()
