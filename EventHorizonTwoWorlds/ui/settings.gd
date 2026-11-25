extends Control

func _on_master_changed(value: float) -> void:
	AudioManager.set_master_volume(value)

func _on_music_changed(value: float) -> void:
	if value <= 0.001:
		AudioManager.active_player.volume_db = -80.0
	else:
		AudioManager.active_player.volume_db = linear_to_db(value) - 8.0

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
