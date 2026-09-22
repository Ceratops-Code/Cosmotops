extends Node2D


const PlanetScene := preload("res://scripts/planet.gd")
const ShipScene := preload("res://scripts/player_ship.gd")
const MeteorScene := preload("res://scripts/meteor.gd")
const VIEW_SIZE := Vector2(1280.0, 720.0)
const SHIP_BOUNDS := Rect2(35.0, 92.0, 1210.0, 590.0)

enum GameState { MENU, COUNTDOWN, PLAYING, FINALE, RESULTS }

var state := GameState.MENU
var palette := [
	Color("41f4c6"), Color("46a8ff"), Color("ff4e9c"),
	Color("ffc857"), Color("a879ff"), Color("76ed55")
]
var color_names := ["Comet Mint", "Orbit Blue", "Nova Pink", "Solar Gold", "Nebula Violet", "Alien Lime"]
var selected_color_index := 0
var ship: TrixieShip
var planets: Array[ColorPlanet] = []
var stars: Array[Dictionary] = []
var elapsed_time := 0.0
var final_time := 0.0
var best_time := 0.0
var captured_count := 0
var total_planets := 0
var countdown := 0.0
var finale_impacts := 0
var capture_flash := 0.0
var input_hint_time := 0.0

var touch_id := -1
var touch_origin := Vector2.ZERO
var touch_position := Vector2.ZERO
var touch_vector := Vector2.ZERO
var mouse_steering := false

var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	_make_stars()
	_load_best_time()
	ship = ShipScene.new()
	ship.z_index = 4
	add_child(ship)
	ship.configure(palette[selected_color_index], SHIP_BOUNDS)
	ship.position = Vector2(640.0, 390.0)
	set_process_input(true)
	queue_redraw()


func _process(delta: float) -> void:
	input_hint_time += delta
	capture_flash = move_toward(capture_flash, 0.0, delta * 2.5)
	match state:
		GameState.COUNTDOWN:
			countdown -= delta
			if countdown <= 0.0:
				state = GameState.PLAYING
		GameState.PLAYING:
			elapsed_time += delta
			ship.move_ship(_movement_input(), delta)
			_check_planet_contacts()
		GameState.MENU:
			ship.rotation = lerp_angle(ship.rotation, sin(input_hint_time * 0.6) * 0.08, delta * 2.0)
	queue_redraw()


func _make_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 22091986
	for index in range(150):
		stars.append({
			"position": Vector2(rng.randf_range(0.0, VIEW_SIZE.x), rng.randf_range(0.0, VIEW_SIZE.y)),
			"size": rng.randf_range(0.7, 2.1),
			"phase": rng.randf_range(0.0, TAU),
		})


func _load_best_time() -> void:
	var config := ConfigFile.new()
	if config.load("user://scores.cfg") == OK:
		best_time = float(config.get_value("times", "best", 0.0))


func _save_best_time() -> void:
	if best_time <= 0.0 or final_time < best_time:
		best_time = final_time
		var config := ConfigFile.new()
		config.set_value("times", "best", best_time)
		config.save("user://scores.cfg")


func _spawn_planets() -> void:
	_clear_planets()
	var layout := [
		[Vector2(105, 145), 34.0, Color("e76f51"), false, 2],
		[Vector2(292, 185), 48.0, Color("5c7cfa"), true, 1],
		[Vector2(510, 130), 29.0, Color("e9c46a"), false, 3],
		[Vector2(755, 170), 55.0, Color("9b5de5"), false, 1],
		[Vector2(1027, 143), 38.0, Color("00b4d8"), true, 2],
		[Vector2(1180, 245), 27.0, Color("f77f00"), false, 3],
		[Vector2(165, 365), 53.0, Color("2a9d8f"), false, 1],
		[Vector2(390, 330), 31.0, Color("f28482"), true, 2],
		[Vector2(890, 350), 36.0, Color("84a98c"), false, 3],
		[Vector2(1090, 450), 58.0, Color("577590"), true, 1],
		[Vector2(105, 590), 28.0, Color("ffafcc"), false, 2],
		[Vector2(335, 565), 45.0, Color("90be6d"), false, 3],
		[Vector2(590, 600), 33.0, Color("f9c74f"), true, 1],
		[Vector2(820, 570), 50.0, Color("43aa8b"), false, 2],
		[Vector2(1160, 610), 32.0, Color("f94144"), false, 3],
	]
	for index in range(layout.size()):
		var item: Array = layout[index]
		var planet: ColorPlanet = PlanetScene.new()
		planet.configure(item[1], item[2], item[3], item[4], 1000 + index * 37)
		planet.position = item[0]
		planet.z_index = 2
		add_child(planet)
		planets.append(planet)
	total_planets = planets.size()


func _clear_planets() -> void:
	for planet in planets:
		if is_instance_valid(planet):
			planet.queue_free()
	planets.clear()
	for child in get_children():
		if child is TargetMeteor:
			child.queue_free()


func _start_run() -> void:
	_spawn_planets()
	captured_count = 0
	elapsed_time = 0.0
	final_time = 0.0
	finale_impacts = 0
	countdown = 2.35
	state = GameState.COUNTDOWN
	ship.visible = true
	ship.position = Vector2(640.0, 385.0)
	ship.rotation = 0.0
	ship.configure(palette[selected_color_index], SHIP_BOUNDS)
	ship.stop()
	_clear_touch()


func _check_planet_contacts() -> void:
	for planet in planets:
		if not is_instance_valid(planet) or planet.captured:
			continue
		if ship.position.distance_to(planet.position) <= planet.radius + ship.hit_radius * 0.72:
			if planet.capture(palette[selected_color_index]):
				captured_count += 1
				capture_flash = 1.0
				if captured_count >= total_planets:
					_finish_run()


func _finish_run() -> void:
	state = GameState.FINALE
	final_time = elapsed_time
	ship.stop()
	_save_best_time()
	_clear_touch()
	for index in range(planets.size()):
		var planet := planets[index]
		if not is_instance_valid(planet):
			continue
		var angle := TAU * float(index) / float(planets.size()) + 0.27
		var start := VIEW_SIZE * 0.5 + Vector2.from_angle(angle) * 920.0
		var meteor: TargetMeteor = MeteorScene.new()
		meteor.z_index = 6
		add_child(meteor)
		meteor.setup(start, planet.position, 0.28 + index * 0.095, 1.05 + float(index % 4) * 0.10, planet, -80.0 + float(index % 5) * 38.0)
		meteor.impacted.connect(_on_meteor_impact)


func _on_meteor_impact(planet: Node) -> void:
	if is_instance_valid(planet):
		planet.explode()
	finale_impacts += 1
	capture_flash = 1.0
	if finale_impacts >= total_planets:
		get_tree().create_timer(1.05).timeout.connect(_show_results)


func _show_results() -> void:
	if state == GameState.FINALE:
		state = GameState.RESULTS
		ship.visible = false


func _return_to_menu() -> void:
	_clear_planets()
	state = GameState.MENU
	ship.visible = true
	ship.position = Vector2(640.0, 365.0)
	ship.rotation = 0.0
	ship.configure(palette[selected_color_index], SHIP_BOUNDS)
	ship.stop()
	_clear_touch()


func _movement_input() -> Vector2:
	var movement := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		movement.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		movement.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		movement.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		movement.y += 1.0

	var joypads := Input.get_connected_joypads()
	if not joypads.is_empty():
		var joypad: int = joypads[0]
		var stick := Vector2(
			Input.get_joy_axis(joypad, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(joypad, JOY_AXIS_LEFT_Y)
		)
		if stick.length() > 0.18:
			movement = stick
		var dpad := Vector2(
			float(Input.is_joy_button_pressed(joypad, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(joypad, JOY_BUTTON_DPAD_LEFT)),
			float(Input.is_joy_button_pressed(joypad, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(joypad, JOY_BUTTON_DPAD_UP))
		)
		if dpad.length_squared() > 0.0:
			movement = dpad

	if touch_vector.length_squared() > 0.01:
		movement = touch_vector
	return movement.limit_length(1.0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_LEFT, KEY_A] and state == GameState.MENU:
			_change_color(-1)
		elif event.keycode in [KEY_RIGHT, KEY_D] and state == GameState.MENU:
			_change_color(1)
		elif event.keycode in [KEY_ENTER, KEY_SPACE]:
			if state in [GameState.MENU, GameState.RESULTS]:
				_start_run()
		elif event.keycode == KEY_ESCAPE:
			if state == GameState.RESULTS:
				_return_to_menu()

	elif event is InputEventJoypadButton and event.pressed:
		if state == GameState.MENU and event.button_index == JOY_BUTTON_DPAD_LEFT:
			_change_color(-1)
		elif state == GameState.MENU and event.button_index == JOY_BUTTON_DPAD_RIGHT:
			_change_color(1)
		elif event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
			if state in [GameState.MENU, GameState.RESULTS]:
				_start_run()
		elif event.button_index == JOY_BUTTON_B and state == GameState.RESULTS:
			_return_to_menu()

	elif event is InputEventScreenTouch:
		_handle_pointer(event.position, event.pressed, event.index)
	elif event is InputEventScreenDrag and event.index == touch_id:
		touch_position = event.position
		_update_touch_vector()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_pointer(event.position, event.pressed)
	elif event is InputEventMouseMotion and mouse_steering:
		touch_position = event.position
		_update_touch_vector()


func _handle_pointer(position: Vector2, pressed: bool, pointer_id: int) -> void:
	if pressed:
		if state == GameState.MENU:
			_handle_menu_click(position)
		elif state == GameState.RESULTS:
			_handle_results_click(position)
		elif state == GameState.PLAYING and position.x < VIEW_SIZE.x * 0.62 and touch_id == -1:
			touch_id = pointer_id
			touch_origin = position
			touch_position = position
	else:
		if pointer_id == touch_id:
			_clear_touch()


func _handle_mouse_pointer(position: Vector2, pressed: bool) -> void:
	if pressed:
		if state == GameState.MENU:
			_handle_menu_click(position)
		elif state == GameState.RESULTS:
			_handle_results_click(position)
		elif state == GameState.PLAYING and position.x < VIEW_SIZE.x * 0.62:
			mouse_steering = true
			touch_origin = position
			touch_position = position
	else:
		mouse_steering = false
		if touch_id == -1:
			_clear_touch()


func _update_touch_vector() -> void:
	var offset := touch_position - touch_origin
	touch_vector = (offset / 72.0).limit_length(1.0)
	touch_position = touch_origin + offset.limit_length(72.0)


func _clear_touch() -> void:
	touch_id = -1
	touch_vector = Vector2.ZERO
	mouse_steering = false


func _handle_menu_click(position: Vector2) -> void:
	if Rect2(385.0, 505.0, 105.0, 64.0).has_point(position):
		_change_color(-1)
	elif Rect2(790.0, 505.0, 105.0, 64.0).has_point(position):
		_change_color(1)
	elif Rect2(490.0, 600.0, 300.0, 72.0).has_point(position):
		_start_run()


func _handle_results_click(position: Vector2) -> void:
	if Rect2(400.0, 545.0, 230.0, 72.0).has_point(position):
		_start_run()
	elif Rect2(650.0, 545.0, 230.0, 72.0).has_point(position):
		_return_to_menu()


func _change_color(step: int) -> void:
	selected_color_index = wrapi(selected_color_index + step, 0, palette.size())
	ship.configure(palette[selected_color_index], SHIP_BOUNDS)


func _format_time(value: float) -> String:
	var minutes := int(floor(value / 60.0))
	var seconds := fmod(value, 60.0)
	return "%02d:%05.2f" % [minutes, seconds]


func _center_text(text: String, y: float, size: int, color := Color.WHITE) -> void:
	draw_string(font, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW_SIZE.x, size, color)


func _button(rect: Rect2, label: String, color: Color) -> void:
	draw_rect(rect, Color(0.03, 0.04, 0.13, 0.94), true)
	draw_rect(rect, color, false, 3.0)
	draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.66), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 25, Color.WHITE)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("050618"), true)
	draw_circle(Vector2(225.0, 220.0), 230.0, Color(0.16, 0.08, 0.35, 0.13))
	draw_circle(Vector2(1050.0, 555.0), 280.0, Color(0.02, 0.36, 0.43, 0.09))
	for star in stars:
		var twinkle := 0.58 + sin(input_hint_time * 1.8 + star["phase"]) * 0.25
		draw_circle(star["position"], star["size"], Color(0.82, 0.90, 1.0, twinkle))

	match state:
		GameState.MENU:
			_draw_menu()
		GameState.COUNTDOWN:
			_draw_game_hud()
			var count_text := "GO!" if countdown < 0.55 else str(ceili(countdown - 0.35))
			_center_text(count_text, 400.0, 92, palette[selected_color_index])
		GameState.PLAYING:
			_draw_game_hud()
			_draw_touch_stick()
		GameState.FINALE:
			_draw_game_hud()
			_center_text("SYSTEM PAINTED!", 70.0, 31, palette[selected_color_index])
		GameState.RESULTS:
			_draw_results()


func _draw_menu() -> void:
	_center_text("COSMOTOPS", 115.0, 72, Color("f3f7ff"))
	_center_text("TRIXIE'S PLANET RUSH", 157.0, 27, palette[selected_color_index])
	_center_text("Paint every planet. Beat your best time.", 205.0, 20, Color("aeb9d8"))
	_center_text("TRIXIE'S SHIP COLOR", 475.0, 18, Color("aeb9d8"))
	_button(Rect2(385.0, 505.0, 105.0, 64.0), "<", palette[selected_color_index])
	_button(Rect2(790.0, 505.0, 105.0, 64.0), ">", palette[selected_color_index])
	draw_rect(Rect2(505.0, 505.0, 270.0, 64.0), Color(palette[selected_color_index], 0.18), true)
	draw_rect(Rect2(505.0, 505.0, 270.0, 64.0), palette[selected_color_index], false, 3.0)
	draw_string(font, Vector2(505.0, 547.0), color_names[selected_color_index], HORIZONTAL_ALIGNMENT_CENTER, 270.0, 23, Color.WHITE)
	_button(Rect2(490.0, 600.0, 300.0, 72.0), "START RUN", palette[selected_color_index])
	_center_text("Keyboard: WASD / arrows    Gamepad: left stick / D-pad    Touch: drag", 704.0, 16, Color("7f8bae"))


func _draw_game_hud() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, 82.0), Color(0.015, 0.02, 0.08, 0.90), true)
	draw_string(font, Vector2(28.0, 49.0), "COSMOTOPS", HORIZONTAL_ALIGNMENT_LEFT, 260.0, 25, palette[selected_color_index])
	draw_string(font, Vector2(510.0, 49.0), _format_time(final_time if state == GameState.FINALE else elapsed_time), HORIZONTAL_ALIGNMENT_CENTER, 260.0, 29, Color.WHITE)
	draw_string(font, Vector2(1000.0, 49.0), "%d / %d PLANETS" % [captured_count, total_planets], HORIZONTAL_ALIGNMENT_RIGHT, 250.0, 21, Color("dbe5ff"))
	if capture_flash > 0.0:
		draw_rect(Rect2(0.0, 79.0, VIEW_SIZE.x * capture_flash, 3.0), palette[selected_color_index], true)


func _draw_touch_stick() -> void:
	var origin := touch_origin if touch_id != -1 or mouse_steering else Vector2(105.0, 625.0)
	var knob := touch_position if touch_id != -1 or mouse_steering else origin
	draw_circle(origin, 53.0, Color(0.75, 0.82, 1.0, 0.10))
	draw_arc(origin, 53.0, 0.0, TAU, 40, Color(0.75, 0.82, 1.0, 0.30), 2.0, true)
	draw_circle(knob, 23.0, Color(palette[selected_color_index], 0.34))


func _draw_results() -> void:
	draw_rect(Rect2(300.0, 128.0, 680.0, 510.0), Color(0.025, 0.03, 0.12, 0.96), true)
	draw_rect(Rect2(300.0, 128.0, 680.0, 510.0), palette[selected_color_index], false, 4.0)
	_center_text("GALAXY COMPLETE", 220.0, 46, palette[selected_color_index])
	_center_text("Trixie painted every planet", 264.0, 20, Color("b9c6e7"))
	_center_text(_format_time(final_time), 375.0, 68, Color.WHITE)
	_center_text("BEST  " + _format_time(best_time), 435.0, 23, Color("ffd777"))
	_button(Rect2(400.0, 545.0, 230.0, 72.0), "RUN AGAIN", palette[selected_color_index])
	_button(Rect2(650.0, 545.0, 230.0, 72.0), "MENU", Color("8291b9"))
