extends Area2D

signal victory_requested

var unlocked: bool = false
var open: bool = false
var door_offset: float = 0.0
var door_tween: Tween

func set_unlocked(value: bool) -> void:
	if unlocked == value:
		return
	unlocked = value
	open = unlocked
	if door_tween:
		door_tween.kill()
	if open:
		door_tween = create_tween()
		door_tween.tween_method(_set_door_offset, door_offset, -155.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		door_tween = create_tween()
		door_tween.tween_method(_set_door_offset, door_offset, 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()

func _set_door_offset(value: float) -> void:
	door_offset = value
	queue_redraw()

func reset() -> void:
	if door_tween:
		door_tween.kill()
	unlocked = false
	open = false
	door_offset = 0.0
	$DoorVisual.position = Vector2.ZERO
	queue_redraw()

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if open and body.is_in_group("player"):
		victory_requested.emit()

func _draw() -> void:
	var color := Color("#67d7b1") if unlocked else Color("#b94d58")
	draw_rect(Rect2(-52, -72, 104, 144), Color("#182b3a"))
	draw_rect(Rect2(-44, -64, 88, 128), color.darkened(0.55), false, 5.0)
	var door_y := door_offset
	draw_rect(Rect2(-34, -54 + door_y, 68, 108), color if not open else Color("#101923"))
	if open:
		draw_rect(Rect2(-34, -54 + door_y, 68, 18), Color("#67d7b1"))
	else:
		draw_circle(Vector2(24, door_y), 5.0, Color("#efffff"))
