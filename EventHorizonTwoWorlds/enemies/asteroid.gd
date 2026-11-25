extends Area2D
## Falling asteroid used in Level 1.

var velocity := Vector2.ZERO
var spin := 0.0

func setup(start_position: Vector2, target: Vector2, multiplier: float) -> void:
	position = start_position
	velocity = (target - start_position).normalized().rotated(randf_range(-0.12, 0.12)) * randf_range(55.0, 100.0) * multiplier
	spin = randf_range(-2.5, 2.5)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += velocity * delta
	rotation += spin * delta
	if not get_viewport_rect().grow(80).has_point(position):
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.take_damage():
		queue_free()
