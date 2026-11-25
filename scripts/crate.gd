extends RigidBody2D

@export var max_speed: float = 340.0
var gravity_manager: Node
var spawn_position: Vector2

func _ready() -> void:
	spawn_position = global_position
	var root_scene := get_tree().current_scene
	if root_scene != null:
		gravity_manager = root_scene.get_node_or_null("GravityManager")

func reset() -> void:
	global_position = spawn_position
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	freeze = false
	set_sleeping(false)

func _physics_process(_delta: float) -> void:
	if gravity_manager == null:
		return
	apply_central_force(gravity_manager.get_acceleration() * mass)
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed
	linear_velocity *= 0.995
	angular_velocity *= 0.98

func _draw() -> void:
	draw_rect(Rect2(-30, -30, 60, 60), Color("#6f5a35"), true)
	draw_rect(Rect2(-26, -26, 52, 52), Color("#c78a3d"), false, 4.0)
	draw_line(Vector2(-24, -24), Vector2(24, 24), Color("#f1c66d"), 3.0)
	draw_line(Vector2(24, -24), Vector2(-24, 24), Color("#f1c66d"), 3.0)
	draw_rect(Rect2(-12, -5, 24, 10), Color("#4b4031"))
	draw_circle(Vector2(-20, -20), 3.0, Color("#ffe8a7"))
	draw_circle(Vector2(20, -20), 3.0, Color("#ffe8a7"))
	draw_circle(Vector2(-20, 20), 3.0, Color("#ffe8a7"))
	draw_circle(Vector2(20, 20), 3.0, Color("#ffe8a7"))
