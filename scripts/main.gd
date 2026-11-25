extends Node2D

const PlayerScene = preload("res://scenes/player.tscn")
const CrateScene = preload("res://scenes/crate.tscn")
const PlateScene = preload("res://scenes/pressure_plate.tscn")
const DoorScene = preload("res://scenes/exit_door.tscn")

enum State { MAIN_MENU, PLAYING, PAUSED, VICTORY }

var state: State = State.MAIN_MENU
var player: CharacterBody2D
var crate: RigidBody2D
var plate: Area2D
var door: Area2D
var gravity_manager: Node
var hud: CanvasLayer
var overlay: Control
var tutorial_visible: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_build_room()
	_build_ui()
	_show_main_menu()

func _setup_input() -> void:
	var bindings := {
		"move_up": [KEY_W], "move_left": [KEY_A], "move_down": [KEY_S], "move_right": [KEY_D],
		"gravity_up": [KEY_UP], "gravity_down": [KEY_DOWN], "gravity_left": [KEY_LEFT], "gravity_right": [KEY_RIGHT],
		"restart": [KEY_R], "pause": [KEY_ESCAPE]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

func _build_room() -> void:
	gravity_manager = preload("res://scripts/gravity_manager.gd").new()
	gravity_manager.name = "GravityManager"
	add_child(gravity_manager)
	gravity_manager.gravity_changed.connect(_on_gravity_changed)

	_create_walls()
	player = PlayerScene.instantiate()
	player.position = Vector2(170, 520)
	add_child(player)
	crate = CrateScene.instantiate()
	crate.position = Vector2(510, 210)
	add_child(crate)
	plate = PlateScene.instantiate()
	plate.position = Vector2(1050, 560)
	add_child(plate)
	plate.plate_changed.connect(_on_plate_changed)
	door = DoorScene.instantiate()
	door.position = Vector2(1175, 360)
	add_child(door)
	door.victory_requested.connect(_on_victory)

	# A single central pillar makes the room feel damaged and prevents a trivial linear push.
	_create_static_box(Vector2(760, 350), Vector2(90, 90))

func _create_walls() -> void:
	_create_static_box(Vector2(640, 50), Vector2(1120, 20))
	_create_static_box(Vector2(640, 670), Vector2(1120, 20))
	_create_static_box(Vector2(70, 360), Vector2(20, 620))
	_create_static_box(Vector2(1206, 185), Vector2(20, 250))
	_create_static_box(Vector2(1206, 535), Vector2(20, 270))
	_create_static_box(Vector2(1250, 360), Vector2(20, 620))

func _create_static_box(position: Vector2, size: Vector2) -> Node:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)
	return body

func _build_ui() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLAYING and tutorial_visible:
		var key_pressed := event is InputEventKey and event.pressed and not event.echo
		var mouse_pressed := event is InputEventMouseButton and event.pressed
		if key_pressed or mouse_pressed:
			tutorial_visible = false
			_update_hud()

	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			_show_pause()
		elif state == State.PAUSED:
			_resume()
		return
	if event.is_action_pressed("restart"):
		if state == State.PLAYING:
			restart_puzzle()
		return
	if state != State.PLAYING:
		return
	if event.is_action_pressed("gravity_up"):
		gravity_manager.set_direction(Vector2.UP)
	elif event.is_action_pressed("gravity_down"):
		gravity_manager.set_direction(Vector2.DOWN)
	elif event.is_action_pressed("gravity_left"):
		gravity_manager.set_direction(Vector2.LEFT)
	elif event.is_action_pressed("gravity_right"):
		gravity_manager.set_direction(Vector2.RIGHT)

func _on_gravity_changed(direction: Vector2) -> void:
	_update_hud()
	queue_redraw()

func _on_plate_changed(active: bool) -> void:
	door.set_unlocked(active)
	_update_hud()

func _on_victory() -> void:
	if state != State.PLAYING:
		return
	state = State.VICTORY
	get_tree().paused = true
	_show_victory()

func restart_puzzle() -> void:
	player.reset()
	crate.reset()
	plate.reset()
	door.reset()
	gravity_manager.set_direction(Vector2.DOWN)
	state = State.PLAYING
	get_tree().paused = false
	_update_hud()

func _show_main_menu() -> void:
	state = State.MAIN_MENU
	get_tree().paused = true
	_clear_overlay()
	var panel := _overlay_panel()
	var title := Label.new()
	title.text = "GRAVITY IS BROKEN"
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(240, 180)
	title.size = Vector2(800, 70)
	panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ABANDONED STATION // EMERGENCY SYSTEMS ACTIVE"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(300, 255)
	subtitle.size = Vector2(680, 30)
	panel.add_child(subtitle)
	_add_button(panel, "START", Vector2(500, 340), _start_game)
	_add_button(panel, "CONTROLS", Vector2(500, 405), _show_controls)
	_add_button(panel, "QUIT", Vector2(500, 470), func():
		get_tree().quit()
	)

func _show_controls() -> void:
	_clear_overlay()
	var panel := _overlay_panel()
	var title := Label.new()
	title.text = "CONTROLS"
	title.add_theme_font_size_override("font_size", 38)
	title.position = Vector2(500, 150)
	title.size = Vector2(280, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var text := Label.new()
	text.text = "MOVE:  W A S D\nCHANGE GRAVITY:  UP / DOWN / LEFT / RIGHT\nRESTART:  R\nPAUSE:  ESCAPE"
	text.add_theme_font_size_override("font_size", 24)
	text.position = Vector2(420, 230)
	text.size = Vector2(440, 170)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(text)
	_add_button(panel, "BACK", Vector2(500, 440), _show_main_menu)

func _start_game() -> void:
	_clear_overlay()
	state = State.PLAYING
	get_tree().paused = false
	tutorial_visible = true
	restart_puzzle()

func _show_pause() -> void:
	state = State.PAUSED
	get_tree().paused = true
	_clear_overlay()
	var panel := _overlay_panel()
	_add_title(panel, "PAUSED", 220)
	_add_button(panel, "RESUME", Vector2(500, 300), _resume)
	_add_button(panel, "RESTART", Vector2(500, 365), func():
		_clear_overlay()
		restart_puzzle()
	)
	_add_button(panel, "MAIN MENU", Vector2(500, 430), _show_main_menu)

func _resume() -> void:
	_clear_overlay()
	state = State.PLAYING
	get_tree().paused = false

func _show_victory() -> void:
	_clear_overlay()
	var panel := _overlay_panel()
	_add_title(panel, "ESCAPE SUCCESSFUL", 190)
	var sub := Label.new()
	sub.text = "Station systems restored"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(390, 270)
	sub.size = Vector2(500, 40)
	sub.add_theme_font_size_override("font_size", 24)
	panel.add_child(sub)
	_add_button(panel, "RESTART", Vector2(500, 350), func():
		_clear_overlay()
		restart_puzzle()
	)
	_add_button(panel, "MAIN MENU", Vector2(500, 415), _show_main_menu)

func _overlay_panel() -> Panel:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	overlay.add_child(panel)
	return panel

func _clear_overlay() -> void:
	for child in overlay.get_children():
		child.queue_free()

func _add_title(panel: Control, text: String, y_pos: float) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 42)
	label.position = Vector2(300, y_pos)
	label.size = Vector2(680, 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

func _add_button(parent: Control, text: String, position: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = Vector2(280, 48)
	button.pressed.connect(callback)
	button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	parent.add_child(button)

func _update_hud() -> void:
	if hud == null:
		return
	for child in hud.get_children():
		child.queue_free()
	if state != State.PLAYING:
		return
	var panel := Panel.new()
	panel.position = Vector2(20, 110)
	panel.size = Vector2(1240, 78)
	hud.add_child(panel)
	var dir_name := "DOWN"
	if gravity_manager.direction == Vector2.UP: dir_name = "UP"
	elif gravity_manager.direction == Vector2.LEFT: dir_name = "LEFT"
	elif gravity_manager.direction == Vector2.RIGHT: dir_name = "RIGHT"
	var gravity_label := Label.new()
	gravity_label.text = "GRAVITY: " + dir_name
	gravity_label.position = Vector2(20, 14)
	gravity_label.size = Vector2(250, 30)
	gravity_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(gravity_label)
	var plate_label := Label.new()
	plate_label.text = "PLATE: " + ("ACTIVE" if plate.active else "INACTIVE")
	plate_label.position = Vector2(300, 14)
	plate_label.size = Vector2(250, 30)
	plate_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(plate_label)
	var door_label := Label.new()
	door_label.text = "EXIT: " + ("OPEN" if door.unlocked else "LOCKED")
	door_label.position = Vector2(560, 14)
	door_label.size = Vector2(250, 30)
	door_label.add_theme_font_size_override("font_size", 22)
	panel.add_child(door_label)
	var objective := Label.new()
	objective.text = "Move the amber crate onto the plate"
	objective.position = Vector2(820, 14)
	objective.size = Vector2(400, 30)
	objective.add_theme_font_size_override("font_size", 20)
	panel.add_child(objective)
	var controls := Label.new()
	controls.text = "WASD move  |  Arrow keys gravity  |  R restart  |  Esc pause"
	controls.position = Vector2(20, 48)
	controls.size = Vector2(1200, 24)
	controls.add_theme_font_size_override("font_size", 16)
	panel.add_child(controls)
	if tutorial_visible:
		var tutorial := Panel.new()
		tutorial.position = Vector2(340, 610)
		tutorial.size = Vector2(600, 70)
		hud.add_child(tutorial)
		var tlabel := Label.new()
		tlabel.text = "Use arrows to change gravity.\nMove the crate onto the yellow plate."
		tlabel.position = Vector2(20, 8)
		tlabel.size = Vector2(560, 54)
		tlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tlabel.add_theme_font_size_override("font_size", 20)
		tutorial.add_child(tlabel)

func _draw() -> void:
	# Deep station floor
	draw_rect(Rect2(80, 60, 1120, 600), Color("#182936"))
	for y in range(70, 660, 60):
		for x in range(90, 1190, 70):
			draw_rect(Rect2(x, y, 62, 52), Color("#203747"), false, 1.0)
	# Outer wall highlights
	draw_rect(Rect2(80, 60, 1120, 18), Color("#456174"))
	draw_rect(Rect2(80, 642, 1120, 18), Color("#2d4657"))
	draw_rect(Rect2(80, 60, 18, 600), Color("#365164"))
	draw_rect(Rect2(1196, 60, 18, 250), Color("#365164"))
	draw_rect(Rect2(1196, 400, 18, 260), Color("#365164"))
	# Red damaged equipment hints
	draw_rect(Rect2(95, 95, 110, 38), Color("#3a2730"))
	draw_line(Vector2(105, 114), Vector2(195, 114), Color("#a94d54"), 5.0)
	draw_circle(Vector2(195, 114), 5.0, Color("#e36b70"))
	# Central structural pillar; matches the collision body in _create_walls.
	draw_rect(Rect2(715, 305, 90, 90), Color("#334b5c"))
	draw_rect(Rect2(723, 313, 74, 74), Color("#1d3140"), false, 4.0)
	draw_circle(Vector2(760, 350), 8.0, Color("#d4a95d"))
