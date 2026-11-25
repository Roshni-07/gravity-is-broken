extends Node

signal gravity_changed(direction: Vector2)

var gravity_magnitude: float = 620.0
var direction: Vector2 = Vector2.DOWN

func set_direction(new_direction: Vector2) -> void:
	if direction == new_direction:
		return
	direction = new_direction.normalized()
	gravity_changed.emit(direction)

func get_acceleration() -> Vector2:
	return direction * gravity_magnitude
