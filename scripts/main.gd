extends Node2D

const PlayerScene = preload("res://scenes/player.tscn")
const CrateScene = preload("res://scenes/crate.tscn")
const PlateScene = preload("res://scenes/pressure_plate.tscn")
const DoorScene = preload("res://scenes/exit_door.tscn")

enum State { MAIN_MENU, LEVEL_SELECT, CONTROLS, SETTINGS, PLAYING, PAUSED, VICTORY }

var state: State = State.MAIN_MENU
var current_level: int = 1
var unlocked_level: int = 1
var completed_levels: Array[int] = []
var gravity_manager: Node
var player: CharacterBody2D
var crates: Array[RigidBody2D] = []
var plates: Array[Area2D] = []
var door: Area2D
var level_nodes: Array[Node] = []
var hud: CanvasLayer
var overlay: Control
var tutorial_visible: bool = true
var settings_sound: bool = true

var level_names := ["", "THE AWAKENING", "THE ORBITAL SHIFT", "THE CORE"]
var level_themes := ["", "CYAN / BLUE", "PURPLE / MAGENTA", "ORANGE / GOLD"]
var level_objectives := ["", "Move the crate onto the pressure plate.", "Activate both pressure plates.", "Activate both reactor mechanisms."]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_build_ui()
	gravity_manager = preload("res://scripts/gravity_manager.gd").new()
	gravity_manager.name = "GravityManager"
	add_child(gravity_manager)
	gravity_manager.gravity_changed.connect(_on_gravity_changed)
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

func _build_ui() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
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
			restart_level()
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

func _clear_level() -> void:
	for node in level_nodes:
		if is_instance_valid(node):
			node.queue_free()
	level_nodes.clear()
	crates.clear()
	plates.clear()
	player = null
	door = null

func load_level(index: int) -> void:
	if index < 1 or index > 3:
		return
	if index > unlocked_level:
		return
	current_level = index
	_clear_level()
	_clear_overlay()
	_create_walls()
	_create_floor_details()
	_create_player()
	_create_puzzle(index)
	gravity_manager.set_direction(Vector2.DOWN)
	state = State.PLAYING
	tutorial_visible = true
	get_tree().paused = false
	_update_hud()
	queue_redraw()

func restart_level() -> void:
	load_level(current_level)

func _create_player() -> void:
	player = PlayerScene.instantiate()
	player.position = Vector2(170, 520)
	add_child(player)
	level_nodes.append(player)

func _create_puzzle(index: int) -> void:
	var crate_positions: Array[Vector2]
	var plate_positions: Array[Vector2]
	if index == 1:
		crate_positions = [Vector2(510, 210)]
		plate_positions = [Vector2(1050, 560)]
		_create_static_box(Vector2(760, 350), Vector2(90, 90))
	elif index == 2:
		crate_positions = [Vector2(510, 210), Vector2(510, 560)]
		plate_positions = [Vector2(950, 560), Vector2(1050, 210)]
		_create_static_box(Vector2(760, 350), Vector2(90, 260))
	else:
		crate_positions = [Vector2(510, 210), Vector2(800, 210), Vector2(1050, 210)]
		plate_positions = [Vector2(950, 560), Vector2(600, 560)]
		_create_static_box(Vector2(760, 350), Vector2(170, 55))
		_create_static_box(Vector2(760, 470), Vector2(55, 170))

	for position in crate_positions:
		var crate: RigidBody2D = CrateScene.instantiate()
		crate.position = position
		add_child(crate)
		crates.append(crate)
		level_nodes.append(crate)
	for position in plate_positions:
		var plate: Area2D = PlateScene.instantiate()
		plate.position = position
		plate.connect("plate_changed", _on_plate_changed)
		add_child(plate)
		plates.append(plate)
		level_nodes.append(plate)

	door = DoorScene.instantiate()
	door.position = Vector2(1175, 360)
	door.connect("victory_requested", _on_victory)
	add_child(door)
	level_nodes.append(door)

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
	level_nodes.append(body)
	return body

func _create_floor_details() -> void:
	pass

func _on_gravity_changed(_direction: Vector2) -> void:
	_update_hud()
	queue_redraw()

func _is_plate_active(plate: Area2D) -> bool:
	return bool(plate.get("active"))

func _on_plate_changed(_active: bool) -> void:
	var all_active := plates.size() > 0
	for plate in plates:
		if not _is_plate_active(plate):
			all_active = false
			break
	if is_instance_valid(door):
		door.call("set_unlocked", all_active)
	_update_hud()

func _on_victory() -> void:
	if state != State.PLAYING:
		return
	var all_active := plates.size() > 0
	for plate in plates:
		if not _is_plate_active(plate):
			all_active = false
			break
	if not all_active:
		return
	state = State.VICTORY
	if not completed_levels.has(current_level):
		completed_levels.append(current_level)
	if current_level >= unlocked_level and current_level < 3:
		unlocked_level = current_level + 1
	get_tree().paused = true
	_show_victory()

func _show_main_menu() -> void:
	_clear_level()
	state = State.MAIN_MENU
	get_tree().paused = true
	_clear_overlay()
	var panel := _overlay_panel()
	_add_title(panel, "GRAVITY IS BROKEN", 150, 52)
	_add_subtitle(panel, "ABANDONED STATION // THREE GRAVITY PUZZLES", 220)
	_add_button(panel, "PLAY", Vector2(500, 300), func(): load_level(1))
	_add_button(panel, "LEVEL SELECT", Vector2(500, 355), _show_level_select)
	_add_button(panel, "CONTROLS", Vector2(500, 410), _show_controls)
	_add_button(panel, "SETTINGS", Vector2(500, 465), _show_settings)
	_add_button(panel, "QUIT", Vector2(500, 520), func(): get_tree().quit())
	_update_hud()

func _show_level_select() -> void:
	state = State.LEVEL_SELECT
	_clear_overlay()
	var panel := _overlay_panel()
	_add_title(panel, "LEVEL SELECT", 80, 42)
	var cards := [Vector2(130, 180), Vector2(500, 180), Vector2(870, 180)]
	for i in range(3):
		var index := i + 1
		var card := Panel.new()
		card.position = cards[i]
		card.size = Vector2(320, 350)
		panel.add_child(card)
		var title := Label.new()
		title.text = "%d  %s" % [index, level_names[index]]
		title.position = Vector2(20, 25)
		title.size = Vector2(280, 55)
		title.add_theme_font_size_override("font_size", 22)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(title)
		var theme := Label.new()
		theme.text = level_themes[index]
		theme.position = Vector2(20, 90)
		theme.size = Vector2(280, 30)
		theme.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(theme)
		var status_text := "LOCKED"
		if index <= unlocked_level:
			status_text = "COMPLETED" if completed_levels.has(index) else "AVAILABLE"
		var status := Label.new()
		status.text = status_text
		status.position = Vector2(20, 145)
		status.size = Vector2(280, 30)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(status)
		var objective := Label.new()
		objective.text = level_objectives[index]
		objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		objective.position = Vector2(30, 190)
		objective.size = Vector2(260, 65)
		objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(objective)
		if index <= unlocked_level:
			var selected_level := index
			_add_button(card, "PLAY", Vector2(20, 280), func(): load_level(selected_level))
	_add_button(panel, "BACK", Vector2(500, 580), _show_main_menu)

func _show_controls() -> void:
	state = State.CONTROLS
	_clear_overlay()
	var panel := _overlay_panel()
	_add_title(panel, "CONTROLS", 130, 42)
	var text := Label.new()
	text.text = "MOVE:  W A S D\nCHANGE GRAVITY:  UP / DOWN / LEFT / RIGHT\nRESTART LEVEL:  R\nPAUSE:  ESCAPE"
	text.add_theme_font_size_override("font_size", 24)
	text.position = Vector2(420, 220)
	text.size = Vector2(440, 180)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(text)
	_add_button(panel, "BACK", Vector2(500, 440), _show_main_menu)

func _show_settings() -> void:
	state = State.SETTINGS
	_clear_overlay()
	var panel := _overlay_panel()
	_add_title(panel, "SETTINGS", 130, 42)
	var label := Label.new()
	label.text = "Feedback sounds: " + ("ON" if settings_sound else "OFF")
	label.position = Vector2(390, 260)
	label.size = Vector2(500, 40)
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	_add_button(panel, "TOGGLE", Vector2(500, 340), func():
		settings_sound = not settings_sound
		_show_settings()
	)
	_add_button(panel, "BACK", Vector2(500, 410), _show_main_menu)

func _show_pause() -> void:
	state = State.PAUSED
	get_tree().paused = true
	_clear_overlay()
	var panel := _overlay_panel()
	_add_title(panel, "PAUSED", 220, 42)
	_add_button(panel, "RESUME", Vector2(500, 300), _resume)
	_add_button(panel, "RESTART", Vector2(500, 365), func(): restart_level())
	_add_button(panel, "MAIN MENU", Vector2(500, 430), _show_main_menu)

func _resume() -> void:
	_clear_overlay()
	state = State.PLAYING
	get_tree().paused = false
	_update_hud()

func _show_victory() -> void:
	_clear_overlay()
	var panel := _overlay_panel()
	_add_title(panel, "LEVEL COMPLETED", 180, 42)
	var sub := Label.new()
	sub.text = level_names[current_level]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(390, 260)
	sub.size = Vector2(500, 40)
	sub.add_theme_font_size_override("font_size", 24)
	panel.add_child(sub)
	if current_level < 3:
		_add_button(panel, "NEXT LEVEL", Vector2(500, 330), func(): load_level(current_level + 1))
	_add_button(panel, "REPLAY", Vector2(500, 395), func(): restart_level())
	_add_button(panel, "MAIN MENU", Vector2(500, 460), _show_main_menu)

func _overlay_panel() -> Panel:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	overlay.add_child(panel)
	return panel

func _clear_overlay() -> void:
	for child in overlay.get_children():
		child.queue_free()

func _add_title(parent: Control, text: String, y_pos: float, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.position = Vector2(300, y_pos)
	label.size = Vector2(680, 60)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

func _add_subtitle(parent: Control, text: String, y_pos: float) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(300, y_pos)
	label.size = Vector2(680, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)

func _add_button(parent: Control, text: String, position: Vector2, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = Vector2(280, 48)
	button.pressed.connect(callback)
	button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	parent.add_child(button)

func _update_hud() -> void:
	for child in hud.get_children():
		child.queue_free()
	if state != State.PLAYING:
		return
	var panel := Panel.new()
	panel.position = Vector2(20, 20)
	panel.size = Vector2(1240, 78)
	hud.add_child(panel)
	var dir_name := "DOWN"
	if gravity_manager.direction == Vector2.UP:
		dir_name = "UP"
	elif gravity_manager.direction == Vector2.LEFT:
		dir_name = "LEFT"
	elif gravity_manager.direction == Vector2.RIGHT:
		dir_name = "RIGHT"
	var active_count := 0
	for plate in plates:
		if _is_plate_active(plate):
			active_count += 1
	var label := Label.new()
	label.text = "LEVEL %d - %s" % [current_level, level_names[current_level]]
	label.position = Vector2(20, 8)
	label.size = Vector2(390, 24)
	panel.add_child(label)
	var objective := Label.new()
	objective.text = level_objectives[current_level]
	objective.position = Vector2(410, 8)
	objective.size = Vector2(360, 24)
	panel.add_child(objective)
	var gravity := Label.new()
	var gravity_symbol := "▼"
	var gravity_color := Color("#60a5fa")
	if dir_name == "UP":
		gravity_symbol = "▲"
		gravity_color = Color("#63f0ff")
	elif dir_name == "LEFT":
		gravity_symbol = "◀"
		gravity_color = Color("#bd7cff")
	elif dir_name == "RIGHT":
		gravity_symbol = "▶"
		gravity_color = Color("#ff71d3")
	gravity.text = gravity_symbol + " GRAVITY: " + dir_name
	gravity.position = Vector2(790, 8)
	gravity.size = Vector2(200, 24)
	gravity.add_theme_color_override("font_color", gravity_color)
	panel.add_child(gravity)
	var mechanisms := Label.new()
	mechanisms.text = "PLATES: %d/%d" % [active_count, plates.size()]
	mechanisms.position = Vector2(1000, 8)
	mechanisms.size = Vector2(220, 24)
	panel.add_child(mechanisms)
	var pause_button := Button.new()
	pause_button.text = "PAUSE"
	pause_button.position = Vector2(1120, 42)
	pause_button.size = Vector2(100, 28)
	pause_button.pressed.connect(_show_pause)
	panel.add_child(pause_button)
	var restart_button := Button.new()
	restart_button.text = "RESTART"
	restart_button.position = Vector2(1010, 42)
	restart_button.size = Vector2(100, 28)
	restart_button.pressed.connect(restart_level)
	panel.add_child(restart_button)
	var controls := Label.new()
	controls.text = "WASD move  |  Arrows gravity  |  R restart  |  Esc pause"
	controls.position = Vector2(20, 42)
	controls.size = Vector2(980, 24)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(controls)
	if tutorial_visible:
		var tutorial := Panel.new()
		tutorial.position = Vector2(340, 610)
		tutorial.size = Vector2(600, 70)
		hud.add_child(tutorial)
		var tutorial_label := Label.new()
		tutorial_label.text = "WASD: move  |  Arrow keys: change gravity\nCrates follow gravity. Activate every plate, then reach the exit."
		tutorial_label.position = Vector2(20, 8)
		tutorial_label.size = Vector2(560, 54)
		tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tutorial_label.add_theme_font_size_override("font_size", 18)
		tutorial.add_child(tutorial_label)

func _get_theme() -> Dictionary:
	if current_level == 2:
		return {"floor": Color("#25182f"), "grid": Color("#4a2867"), "wall": Color("#b44cff"), "accent": Color("#ff58d6")}
	if current_level == 3:
		return {"floor": Color("#2d1d1a"), "grid": Color("#684022"), "wall": Color("#ff7043"), "accent": Color("#ffc857")}
	return {"floor": Color("#152a38"), "grid": Color("#245268"), "wall": Color("#57d9ff"), "accent": Color("#70f0d0")}

func _draw() -> void:
	var theme := _get_theme()
	draw_rect(Rect2(80, 60, 1120, 600), theme.floor)
	for y in range(70, 660, 60):
		for x in range(90, 1190, 70):
			draw_rect(Rect2(x, y, 62, 52), theme.grid, false, 1.0)
	draw_rect(Rect2(80, 60, 1120, 18), theme.wall)
	draw_rect(Rect2(80, 642, 1120, 18), theme.wall.darkened(0.35))
	draw_rect(Rect2(80, 60, 18, 600), theme.wall.darkened(0.20))
	draw_rect(Rect2(1196, 60, 18, 250), theme.wall)
	draw_rect(Rect2(1196, 400, 18, 260), theme.wall)
	for i in range(18):
		var star_x := 105.0 + float((i * 73) % 1080)
		var star_y := 75.0 + float((i * 47) % 575)
		draw_circle(Vector2(star_x, star_y), 2.0 if i % 3 == 0 else 1.0, theme.accent)
