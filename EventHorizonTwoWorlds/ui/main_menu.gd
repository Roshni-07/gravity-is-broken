extends Control

func _ready() -> void:
	AudioManager.play_music(load("res://assets/gravity/audio/cosmic_ambience.wav"))

func _on_play_pressed() -> void:
	AudioManager.play_sfx("ui")
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://levels/level_01.tscn")

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("ui")
	get_tree().change_scene_to_file("res://ui/settings.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
