extends Control

func _ready() -> void:
	await get_tree().create_timer(2.2).timeout
	get_tree().change_scene_to_file("res://levels/level_02.tscn")
