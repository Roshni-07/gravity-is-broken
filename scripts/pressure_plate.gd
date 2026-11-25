extends Area2D

signal plate_changed(active: bool)

var active: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("cargo"):
		_set_active(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("cargo"):
		call_deferred("_refresh_active_state")

func _refresh_active_state() -> void:
	var cargo_present := false
	for body in get_overlapping_bodies():
		if body.is_in_group("cargo"):
			cargo_present = true
			break
	_set_active(cargo_present)

func reset() -> void:
	_set_active(false)

func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	plate_changed.emit(active)
	queue_redraw()

func _draw() -> void:
	var color := Color("#8bd5b2") if active else Color("#d6a84b")
	draw_rect(Rect2(-74, -74, 148, 148), Color("#263b4b"))
	draw_rect(Rect2(-68, -68, 136, 136), color, false, 6.0)
	draw_circle(Vector2.ZERO, 44.0, color.darkened(0.25))
	draw_circle(Vector2.ZERO, 30.0, color)
