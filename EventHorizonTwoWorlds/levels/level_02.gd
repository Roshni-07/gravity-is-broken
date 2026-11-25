extends Node2D
## Level 2 carries the unified player, shield/speed abilities and score into gravity-platforming.

var portal_locked := true
var gravity_index := 0
var gravity_dirs := [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]

func _ready() -> void:
	AudioManager.play_music(load("res://assets/gravity/audio/cosmic_ambience.wav"))
	$Player.mode = "platform"
	$Player.position = Vector2(180, 560)
	$Player.set_gravity(Vector2.DOWN)
	$HUD.update_state(0.0, GameManager.lives, GameManager.score)
	$Collectible.body_entered.connect(_on_collect_body_entered)
	$Portal.body_entered.connect(_on_portal_body_entered)

func _on_collect_body_entered(body: Node2D) -> void:
	if body == $Player:
		$Collectible.queue_free()
		_on_collect_collected()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("gravity_up"):
		_set_gravity(Vector2.UP)
	elif event.is_action_pressed("gravity_down"):
		_set_gravity(Vector2.DOWN)
	elif event.is_action_pressed("gravity_left"):
		_set_gravity(Vector2.LEFT)
	elif event.is_action_pressed("gravity_right"):
		_set_gravity(Vector2.RIGHT)

func _set_gravity(direction: Vector2) -> void:
	$Player.set_gravity(direction)
	AudioManager.play_sfx("hit_b")

func _on_collect_collected() -> void:
	GameManager.add_score(25)
	AudioManager.play_sfx("collect_b")
	portal_locked = false
	$Portal.modulate = Color.GREEN

func _on_portal_body_entered(body: Node2D) -> void:
	if body == $Player and not portal_locked:
		GameManager.change_scene("res://ui/win.tscn")
