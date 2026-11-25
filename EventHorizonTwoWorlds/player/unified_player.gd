extends CharacterBody2D
## Unified player: 8-way ship controls on Level 1 and gravity-platforming on Level 2.

signal damaged
signal collected

@export var mode := "ship" # "ship" or "platform"
@export var gravity_dir := Vector2.DOWN

var health := 3
var shield_time := 0.0
var speed_time := 0.0

func _ready() -> void:
	add_to_group("player")

func _physics_process(delta: float) -> void:
	shield_time = max(shield_time - delta, 0.0)
	speed_time = max(speed_time - delta, 0.0)
	if mode == "ship":
		_ship_move(delta)
	else:
		_platform_move(delta)
	move_and_slide()

func _ship_move(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := 180.0 if speed_time <= 0 else 300.0
	velocity = direction * speed
	if $Visual:
		$Visual.rotation = lerp($Visual.rotation, direction.x * 0.25, 0.15)

func _platform_move(delta: float) -> void:
	velocity += gravity_dir * 1100.0 * delta
	var up := -gravity_dir
	var tangent := up.rotated(PI / 2.0)
	var axis := Input.get_axis("move_left", "move_right")
	var desired := axis * (230.0 if speed_time <= 0 else 330.0)
	var tangent_speed := velocity.dot(tangent)
	velocity += tangent * (move_toward(tangent_speed, desired, 1800.0 * delta) - tangent_speed)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity += up * 430.0
		AudioManager.play_sfx("jump_b")

func set_gravity(direction: Vector2) -> void:
	gravity_dir = direction
	up_direction = -direction

func take_damage() -> bool:
	if shield_time > 0:
		AudioManager.play_sfx("hit")
		return false
	health -= 1
	damaged.emit()
	AudioManager.play_sfx("hit")
	if health <= 0:
		GameManager.lose_life()
	return true

func apply_power_up(kind: String) -> void:
	if kind == "health":
		health = min(health + 1, 3)
	elif kind == "shield":
		shield_time = 5.0
	elif kind == "speed":
		speed_time = 5.0
	AudioManager.play_sfx("collect")
	collected.emit()
