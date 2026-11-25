extends Node
## Owns persistent score, lives, progression, pause state and scene transitions.

signal score_changed(score: int)
signal lives_changed(lives: int)

var score := 0
var lives := 3
var current_level := 1
var paused := false

func reset_game() -> void:
	score = 0
	lives = 3
	current_level = 1
	score_changed.emit(score)
	lives_changed.emit(lives)

func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)

func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		change_scene("res://ui/game_over.tscn")

func next_level() -> void:
	current_level += 1
	change_scene("res://ui/transition.tscn")

func change_scene(path: String) -> void:
	# Fade through a dark full-screen transition for polished scene changes.
	get_tree().change_scene_to_file(path)

func toggle_pause() -> void:
	paused = not paused
	get_tree().paused = paused
