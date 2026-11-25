extends CharacterBody2D

@export var move_speed: float = 220.0
var spawn_position: Vector2

func _ready() -> void:
	spawn_position = global_position

func reset() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO

func _physics_process(_delta: float) -> void:
	var input_direction := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_direction.length_squared() > 1.0:
		input_direction = input_direction.normalized()
	velocity = input_direction * move_speed
	move_and_slide()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 24.0, Color("#7bdcff"))
	draw_circle(Vector2.ZERO, 19.0, Color("#d9edf3"))
	draw_rect(Rect2(-14, -16, 28, 32), Color("#173a57"))
	draw_circle(Vector2(12, 0), 7.0, Color("#63d5ff"))
	draw_rect(Rect2(-18, 15, 36, 7), Color("#88a8b8"))
	draw_circle(Vector2(20, 0), 4.0, Color("#f0fcff"))
