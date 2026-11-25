extends Node2D
## Level 1 is a survival/dodge level inspired by Game A, with a gravity-beacon hint.

var elapsed := 0.0
var spawn_timer := 0.0
var asteroid_scene := preload("res://levels/asteroid.tscn")

func _ready() -> void:
	AudioManager.play_music(load("res://assets/gravity/audio/cosmic_ambience.wav"))
	GameManager.reset_game()
	$HUD/CollectLabel.text = "Collect 10 shards to cross the breach"

func _process(delta: float) -> void:
	elapsed += delta
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_asteroid()
		spawn_timer = max(0.28, 1.0 - elapsed * 0.012)
	$HUD.update_state(elapsed, GameManager.lives, GameManager.score)
	if elapsed >= 35.0:
		GameManager.next_level()

func spawn_asteroid() -> void:
	var asteroid := asteroid_scene.instantiate()
	var side := randi() % 4
	var pos := Vector2.ZERO
	match side:
		0: pos = Vector2(randf_range(0, 1280), -40)
		1: pos = Vector2(randf_range(0, 1280), 760)
		2: pos = Vector2(-40, randf_range(0, 720))
		3: pos = Vector2(1320, randf_range(0, 720))
	$Asteroids.add_child(asteroid)
	asteroid.setup(pos, $Player.position, 1.0 + elapsed * 0.008)
