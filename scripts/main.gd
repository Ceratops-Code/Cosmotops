extends Node2D


const PlanetScene := preload("res://scripts/planet.gd")
const ShipScene := preload("res://scripts/player_ship.gd")
const MeteorScene := preload("res://scripts/meteor.gd")

const SFX_STREAMS := {
	"click": preload("res://assets/sfx_click.ogg"),
	"countdown": preload("res://assets/sfx_countdown.ogg"),
	"start": preload("res://assets/sfx_start.ogg"),
	"capture": preload("res://assets/sfx_capture.ogg"),
	"meteor": preload("res://assets/sfx_meteor.ogg"),
	"explosion": preload("res://assets/sfx_explosion.ogg"),
}

const VIEW_SIZE := Vector2(1280.0, 720.0)
const SHIP_BOUNDS := Rect2(35.0, 92.0, 1210.0, 590.0)
const SHIP_START := Vector2(640.0, 390.0)

const BACK_BUTTON := Rect2(704.0, 16.0, 128.0, 50.0)
const RESET_BUTTON := Rect2(840.0, 16.0, 128.0, 50.0)
const PAUSE_BUTTON := Rect2(976.0, 16.0, 128.0, 50.0)
const CLOSE_BUTTON := Rect2(1112.0, 16.0, 128.0, 50.0)

const SHIP_LEFT_BUTTON := Rect2(385.0, 370.0, 105.0, 58.0)
const SHIP_NAME_BUTTON := Rect2(505.0, 370.0, 270.0, 58.0)
const SHIP_RIGHT_BUTTON := Rect2(790.0, 370.0, 105.0, 58.0)
const COLOR_LEFT_BUTTON := Rect2(385.0, 475.0, 105.0, 58.0)
const COLOR_NAME_BUTTON := Rect2(505.0, 475.0, 270.0, 58.0)
const COLOR_RIGHT_BUTTON := Rect2(790.0, 475.0, 105.0, 58.0)
const START_BUTTON := Rect2(490.0, 565.0, 300.0, 72.0)
const AGAIN_BUTTON := Rect2(400.0, 545.0, 230.0, 72.0)
const MENU_BUTTON := Rect2(650.0, 545.0, 230.0, 72.0)

enum GameState { MENU, READY, COUNTDOWN, PLAYING, PAUSED, FINALE, RESULTS }

var state := GameState.MENU
var state_before_pause := GameState.PLAYING
var palette := [
	Color("41f4c6"), Color("46a8ff"), Color("ff4e9c"),
	Color("ffc857"), Color("a879ff"), Color("76ed55")
]
var color_names := ["Comet Mint", "Orbit Blue", "Nova Pink", "Solar Gold", "Nebula Violet", "Alien Lime"]
var ship_names := ["Arrow Scout", "Dart Runner", "Nova Wing", "Orbit Saucer"]
var selected_color_index := 0
var selected_ship_index := 0

var ship: TrixieShip
var planets: Array[ColorPlanet] = []
var stars: Array[Dictionary] = []
var elapsed_time := 0.0
var final_time := 0.0
var best_time := 0.0
var captured_count := 0
var total_targets := 0
var countdown_value := 5
var countdown_phase := 0.0
var finale_impacts := 0
var capture_flash := 0.0
var input_hint_time := 0.0
var run_serial := 0

var touch_id := -1
var touch_origin := Vector2.ZERO
var touch_position := Vector2.ZERO
var touch_vector := Vector2.ZERO
var mouse_steering := false

var font: Font
var overlay_layer: CanvasLayer
var overlay_shade: ColorRect
var message_label: Label
var countdown_label: Label


func _ready() -> void:
	font = ThemeDB.fallback_font
	_make_stars()
	_load_best_time()
	_setup_overlay()
	ship = ShipScene.new()
	ship.z_index = 4
	add_child(ship)
	ship.configure(palette[selected_color_index], SHIP_BOUNDS, selected_ship_index)
	ship.position = Vector2(640.0, 270.0)
	ship.scale = Vector2(1.18, 1.18)
	set_process_input(true)
	_update_overlay()
	queue_redraw()


func _process(delta: float) -> void:
	input_hint_time += delta
	capture_flash = move_toward(capture_flash, 0.0, delta * 2.5)
	match state:
		GameState.COUNTDOWN:
			countdown_phase += delta
			while countdown_phase >= 1.0 and state == GameState.COUNTDOWN:
				countdown_phase -= 1.0
				countdown_value -= 1
				if countdown_value <= 0:
					_launch_run()
				else:
					_play_sfx("countdown", 1.0 + float(5 - countdown_value) * 0.08, -4.0)
		GameState.PLAYING:
			elapsed_time += delta
			ship.move_ship(_movement_input(), delta)
			_check_planet_contacts()
		GameState.MENU:
			ship.rotation = lerp_angle(ship.rotation, sin(input_hint_time * 0.6) * 0.08, delta * 2.0)
	_update_overlay()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == GameState.MENU:
			get_tree().quit()
		else:
			_return_to_menu()


func _setup_overlay() -> void:
	# A CanvasLayer keeps countdown and pause messaging above the ship and planets.
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	add_child(overlay_layer)

	overlay_shade = ColorRect.new()
	overlay_shade.position = Vector2.ZERO
	overlay_shade.size = VIEW_SIZE
	overlay_shade.color = Color(0.01, 0.015, 0.06, 0.62)
	overlay_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(overlay_shade)

	message_label = Label.new()
	message_label.position = Vector2(140.0, 270.0)
	message_label.size = Vector2(1000.0, 190.0)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 38)
	message_label.add_theme_constant_override("outline_size", 12)
	message_label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.06, 0.96))
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(message_label)

	countdown_label = Label.new()
	countdown_label.position = Vector2(440.0, 205.0)
	countdown_label.size = Vector2(400.0, 310.0)
	countdown_label.pivot_offset = countdown_label.size * 0.5
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.add_theme_font_size_override("font_size", 220)
	countdown_label.add_theme_constant_override("outline_size", 18)
	countdown_label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.06, 0.98))
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(countdown_label)


func _update_overlay() -> void:
	overlay_shade.visible = false
	message_label.visible = false
	countdown_label.visible = false
	if state == GameState.READY:
		overlay_shade.visible = true
		message_label.visible = true
		message_label.text = "PRESS ANY KEY OR GAMEPAD BUTTON\nTO START  5  •  4  •  3  •  2  •  1"
		message_label.modulate = palette[selected_color_index]
	elif state == GameState.COUNTDOWN:
		countdown_label.visible = true
		countdown_label.text = str(countdown_value)
		var zoom := lerpf(0.30, 3.45, pow(clampf(countdown_phase, 0.0, 1.0), 1.55))
		countdown_label.scale = Vector2.ONE * zoom
		countdown_label.rotation = lerpf(-0.045, 0.045, countdown_phase) * (-1.0 if countdown_value % 2 == 0 else 1.0)
		var fade := 1.0 - clampf((countdown_phase - 0.66) / 0.34, 0.0, 1.0)
		countdown_label.modulate = Color(palette[selected_color_index], fade)
	elif state == GameState.PAUSED:
		overlay_shade.visible = true
		message_label.visible = true
		message_label.text = "PAUSED\nPRESS PAUSE TO RESUME"
		message_label.modulate = palette[selected_color_index]


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


func _body_specs() -> Array[Dictionary]:
	# Radii deliberately compress the real scale while preserving the recognizable hierarchy.
	return [
		{"name": "Jupiter", "radius": 54.0, "style": "jupiter"},
		{"name": "Saturn", "radius": 46.0, "style": "saturn"},
		{"name": "Uranus", "radius": 38.0, "style": "uranus"},
		{"name": "Neptune", "radius": 37.0, "style": "neptune"},
		{"name": "Earth", "radius": 30.0, "style": "earth"},
		{"name": "Venus", "radius": 29.0, "style": "venus"},
		{"name": "Mars", "radius": 22.0, "style": "mars"},
		{"name": "Mercury", "radius": 17.0, "style": "mercury"},
		{"name": "Moon", "radius": 15.0, "style": "moon"},
		{"name": "Makemake", "radius": 13.0, "style": "makemake"},
		{"name": "Asteroid A", "radius": 11.0, "style": "asteroid_a"},
		{"name": "Asteroid B", "radius": 9.0, "style": "asteroid_b"},
	]


func _spawn_planets() -> void:
	_clear_planets()
	run_serial += 1
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Twelve separated cells guarantee a playable layout; assignment and jitter vary each run.
	var slots: Array[Vector2] = [
		Vector2(130.0, 180.0), Vector2(440.0, 180.0), Vector2(840.0, 180.0), Vector2(1150.0, 180.0),
		Vector2(130.0, 390.0), Vector2(440.0, 390.0), Vector2(840.0, 390.0), Vector2(1150.0, 390.0),
		Vector2(130.0, 600.0), Vector2(440.0, 600.0), Vector2(840.0, 600.0), Vector2(1150.0, 600.0),
	]
	var specs := _body_specs()
	for index in range(specs.size()):
		var slot_index := rng.randi_range(0, slots.size() - 1)
		var position_in_space: Vector2 = slots.pop_at(slot_index)
		position_in_space += Vector2(rng.randf_range(-28.0, 28.0), rng.randf_range(-12.0, 12.0))
		var spec: Dictionary = specs[index]
		var planet: ColorPlanet = PlanetScene.new()
		planet.configure(String(spec["name"]), float(spec["radius"]), String(spec["style"]), 1000 + run_serial * 101 + index * 37)
		planet.position = position_in_space
		planet.z_index = 2
		add_child(planet)
		planets.append(planet)
	total_targets = planets.size()


func _clear_planets() -> void:
	for planet in planets:
		if is_instance_valid(planet):
			planet.queue_free()
	planets.clear()
	for child in get_children():
		if child is TargetMeteor:
			child.queue_free()


func _prepare_run() -> void:
	_spawn_planets()
	captured_count = 0
	elapsed_time = 0.0
	final_time = 0.0
	finale_impacts = 0
	countdown_value = 5
	countdown_phase = 0.0
	state = GameState.READY
	ship.visible = true
	ship.position = SHIP_START
	ship.rotation = 0.0
	ship.scale = Vector2.ONE
	ship.configure(palette[selected_color_index], SHIP_BOUNDS, selected_ship_index)
	ship.stop()
	_clear_touch()


func _begin_countdown() -> void:
	if state != GameState.READY:
		return
	state = GameState.COUNTDOWN
	countdown_value = 5
	countdown_phase = 0.0
	_play_sfx("countdown", 1.0, -4.0)


func _launch_run() -> void:
	state = GameState.PLAYING
	countdown_phase = 0.0
	_play_sfx("start", 1.0, -3.0)


func _reset_run() -> void:
	_play_sfx("click", 1.04, -5.0)
	_prepare_run()


func _toggle_pause() -> void:
	if state in [GameState.COUNTDOWN, GameState.PLAYING]:
		state_before_pause = state
		state = GameState.PAUSED
		ship.stop()
		_clear_touch()
		_play_sfx("click", 0.86, -5.0)
	elif state == GameState.PAUSED:
		state = state_before_pause
		_play_sfx("click", 1.10, -5.0)


func _check_planet_contacts() -> void:
	for planet in planets:
		if not is_instance_valid(planet) or planet.captured:
			continue
		if ship.position.distance_to(planet.position) <= planet.radius + ship.hit_radius * 0.72:
			if planet.capture(palette[selected_color_index]):
				captured_count += 1
				capture_flash = 1.0
				_play_sfx("capture", 0.94 + float(captured_count) * 0.012, -5.0)
				if captured_count >= total_targets:
					_finish_run()


func _finish_run() -> void:
	state = GameState.FINALE
	final_time = elapsed_time
	ship.stop()
	_save_best_time()
	_clear_touch()
	_play_sfx("meteor", 1.0, -5.0)
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
	_play_sfx("explosion", 0.88 + float(finale_impacts % 5) * 0.055, -4.0)
	if finale_impacts >= total_targets:
		get_tree().create_timer(1.05).timeout.connect(_show_results)


func _show_results() -> void:
	if state == GameState.FINALE:
		state = GameState.RESULTS
		ship.visible = false


func _return_to_menu() -> void:
	_play_sfx("click", 0.92, -5.0)
	_clear_planets()
	state = GameState.MENU
	ship.visible = true
	ship.position = Vector2(640.0, 270.0)
	ship.rotation = 0.0
	ship.scale = Vector2(1.18, 1.18)
	ship.configure(palette[selected_color_index], SHIP_BOUNDS, selected_ship_index)
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
		var stick := Vector2(Input.get_joy_axis(joypad, JOY_AXIS_LEFT_X), Input.get_joy_axis(joypad, JOY_AXIS_LEFT_Y))
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
		if state == GameState.READY:
			if event.keycode == KEY_ESCAPE:
				_return_to_menu()
			else:
				_begin_countdown()
			return
		if event.keycode == KEY_ESCAPE:
			if state == GameState.MENU:
				get_tree().quit()
			else:
				_return_to_menu()
		elif event.keycode == KEY_P and state in [GameState.COUNTDOWN, GameState.PLAYING, GameState.PAUSED]:
			_toggle_pause()
		elif event.keycode == KEY_R and state != GameState.MENU:
			_reset_run()
		elif state == GameState.MENU:
			if event.keycode in [KEY_LEFT, KEY_A]:
				_change_color(-1)
			elif event.keycode in [KEY_RIGHT, KEY_D]:
				_change_color(1)
			elif event.keycode in [KEY_UP, KEY_W]:
				_change_ship(-1)
			elif event.keycode in [KEY_DOWN, KEY_S]:
				_change_ship(1)
			elif event.keycode in [KEY_ENTER, KEY_SPACE]:
				_play_sfx("click", 1.0, -5.0)
				_prepare_run()
		elif state == GameState.RESULTS and event.keycode in [KEY_ENTER, KEY_SPACE]:
			_play_sfx("click", 1.0, -5.0)
			_prepare_run()

	elif event is InputEventJoypadButton and event.pressed:
		if state == GameState.READY:
			if event.button_index == JOY_BUTTON_B:
				_return_to_menu()
			else:
				_begin_countdown()
			return
		if event.button_index == JOY_BUTTON_B:
			if state != GameState.MENU:
				_return_to_menu()
		elif event.button_index == JOY_BUTTON_START and state in [GameState.COUNTDOWN, GameState.PLAYING, GameState.PAUSED]:
			_toggle_pause()
		elif state == GameState.MENU and event.button_index == JOY_BUTTON_DPAD_LEFT:
			_change_color(-1)
		elif state == GameState.MENU and event.button_index == JOY_BUTTON_DPAD_RIGHT:
			_change_color(1)
		elif state == GameState.MENU and event.button_index == JOY_BUTTON_DPAD_UP:
			_change_ship(-1)
		elif state == GameState.MENU and event.button_index == JOY_BUTTON_DPAD_DOWN:
			_change_ship(1)
		elif event.button_index == JOY_BUTTON_A and state in [GameState.MENU, GameState.RESULTS]:
			_play_sfx("click", 1.0, -5.0)
			_prepare_run()

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
		if _handle_system_button(position):
			return
		if state == GameState.MENU:
			_handle_menu_click(position)
		elif state == GameState.RESULTS:
			_handle_results_click(position)
		elif state == GameState.READY:
			_begin_countdown()
		elif state == GameState.PLAYING and position.x < VIEW_SIZE.x * 0.62 and touch_id == -1:
			touch_id = pointer_id
			touch_origin = position
			touch_position = position
	else:
		if pointer_id == touch_id:
			_clear_touch()


func _handle_mouse_pointer(position: Vector2, pressed: bool) -> void:
	if pressed:
		if _handle_system_button(position):
			return
		if state == GameState.MENU:
			_handle_menu_click(position)
		elif state == GameState.RESULTS:
			_handle_results_click(position)
		elif state == GameState.READY:
			_begin_countdown()
		elif state == GameState.PLAYING and position.x < VIEW_SIZE.x * 0.62:
			mouse_steering = true
			touch_origin = position
			touch_position = position
	else:
		mouse_steering = false
		if touch_id == -1:
			_clear_touch()


func _handle_system_button(position: Vector2) -> bool:
	if CLOSE_BUTTON.has_point(position):
		_play_sfx("click", 0.82, -5.0)
		get_tree().quit()
		return true
	if state == GameState.MENU:
		return false
	if BACK_BUTTON.has_point(position):
		_return_to_menu()
		return true
	if RESET_BUTTON.has_point(position):
		_reset_run()
		return true
	if PAUSE_BUTTON.has_point(position) and state in [GameState.COUNTDOWN, GameState.PLAYING, GameState.PAUSED]:
		_toggle_pause()
		return true
	return false


func _update_touch_vector() -> void:
	var offset := touch_position - touch_origin
	touch_vector = (offset / 72.0).limit_length(1.0)
	touch_position = touch_origin + offset.limit_length(72.0)


func _clear_touch() -> void:
	touch_id = -1
	touch_vector = Vector2.ZERO
	mouse_steering = false


func _handle_menu_click(position: Vector2) -> void:
	if SHIP_LEFT_BUTTON.has_point(position):
		_change_ship(-1)
	elif SHIP_RIGHT_BUTTON.has_point(position):
		_change_ship(1)
	elif COLOR_LEFT_BUTTON.has_point(position):
		_change_color(-1)
	elif COLOR_RIGHT_BUTTON.has_point(position):
		_change_color(1)
	elif START_BUTTON.has_point(position):
		_play_sfx("click", 1.0, -5.0)
		_prepare_run()


func _handle_results_click(position: Vector2) -> void:
	if AGAIN_BUTTON.has_point(position):
		_play_sfx("click", 1.0, -5.0)
		_prepare_run()
	elif MENU_BUTTON.has_point(position):
		_return_to_menu()


func _change_color(step: int) -> void:
	selected_color_index = wrapi(selected_color_index + step, 0, palette.size())
	ship.configure(palette[selected_color_index], SHIP_BOUNDS, selected_ship_index)
	_play_sfx("click", 0.96 + float(selected_color_index) * 0.025, -7.0)


func _change_ship(step: int) -> void:
	selected_ship_index = wrapi(selected_ship_index + step, 0, ship_names.size())
	ship.configure(palette[selected_color_index], SHIP_BOUNDS, selected_ship_index)
	_play_sfx("click", 0.88 + float(selected_ship_index) * 0.07, -7.0)


func _play_sfx(effect: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not SFX_STREAMS.has(effect):
		return
	# One-shot players self-remove, allowing closely spaced meteor impacts to overlap cleanly.
	var player := AudioStreamPlayer.new()
	player.stream = SFX_STREAMS[effect]
	player.pitch_scale = pitch
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _format_time(value: float) -> String:
	var minutes := int(floor(value / 60.0))
	var seconds := fmod(value, 60.0)
	return "%02d:%05.2f" % [minutes, seconds]


func _center_text(text: String, y: float, size: int, color := Color.WHITE) -> void:
	draw_string(font, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, VIEW_SIZE.x, size, color)


func _button(rect: Rect2, label: String, color: Color, enabled := true) -> void:
	var fill := Color(0.03, 0.04, 0.13, 0.94) if enabled else Color(0.03, 0.04, 0.08, 0.72)
	var stroke := color if enabled else Color(color, 0.32)
	var text_color := Color.WHITE if enabled else Color(0.70, 0.74, 0.84, 0.45)
	draw_rect(rect, fill, true)
	draw_rect(rect, stroke, false, 3.0)
	var font_size := 16 if rect.position.y < 100.0 else 24
	draw_string(font, Vector2(rect.position.x, rect.position.y + rect.size.y * 0.66), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, text_color)


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
		GameState.READY, GameState.COUNTDOWN, GameState.PLAYING, GameState.PAUSED:
			_draw_game_hud()
			if state == GameState.PLAYING:
				_draw_touch_stick()
		GameState.FINALE:
			_draw_game_hud()
			_center_text("SOLAR SYSTEM PAINTED!", 112.0, 30, palette[selected_color_index])
		GameState.RESULTS:
			_draw_game_hud()
			_draw_results()


func _draw_menu() -> void:
	_center_text("COSMOTOPS", 88.0, 64, Color("f3f7ff"))
	_center_text("TRIXIE'S SOLAR SYSTEM RUSH", 130.0, 25, palette[selected_color_index])
	_center_text("Paint every world. Beat your best time.", 166.0, 19, Color("aeb9d8"))
	_button(CLOSE_BUTTON, "CLOSE", Color("ff657a"))
	_center_text("TRIXIE'S SHIP", 350.0, 17, Color("aeb9d8"))
	_button(SHIP_LEFT_BUTTON, "<", palette[selected_color_index])
	_button(SHIP_RIGHT_BUTTON, ">", palette[selected_color_index])
	draw_rect(SHIP_NAME_BUTTON, Color(palette[selected_color_index], 0.16), true)
	draw_rect(SHIP_NAME_BUTTON, palette[selected_color_index], false, 3.0)
	draw_string(font, Vector2(SHIP_NAME_BUTTON.position.x, 408.0), ship_names[selected_ship_index], HORIZONTAL_ALIGNMENT_CENTER, SHIP_NAME_BUTTON.size.x, 21, Color.WHITE)
	_center_text("SHIP COLOR", 457.0, 17, Color("aeb9d8"))
	_button(COLOR_LEFT_BUTTON, "<", palette[selected_color_index])
	_button(COLOR_RIGHT_BUTTON, ">", palette[selected_color_index])
	draw_rect(COLOR_NAME_BUTTON, Color(palette[selected_color_index], 0.16), true)
	draw_rect(COLOR_NAME_BUTTON, palette[selected_color_index], false, 3.0)
	draw_string(font, Vector2(COLOR_NAME_BUTTON.position.x, 513.0), color_names[selected_color_index], HORIZONTAL_ALIGNMENT_CENTER, COLOR_NAME_BUTTON.size.x, 21, Color.WHITE)
	_button(START_BUTTON, "READY SHIP", palette[selected_color_index])
	_center_text("WASD / arrows • Gamepad stick / D-pad • Touch drag", 692.0, 16, Color("7f8bae"))


func _draw_game_hud() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_SIZE.x, 82.0), Color(0.015, 0.02, 0.08, 0.94), true)
	draw_string(font, Vector2(18.0, 49.0), "COSMOTOPS", HORIZONTAL_ALIGNMENT_LEFT, 190.0, 23, palette[selected_color_index])
	var shown_time := final_time if state in [GameState.FINALE, GameState.RESULTS] else elapsed_time
	draw_string(font, Vector2(210.0, 49.0), _format_time(shown_time), HORIZONTAL_ALIGNMENT_CENTER, 180.0, 27, Color.WHITE)
	draw_string(font, Vector2(410.0, 48.0), "%d / %d TARGETS" % [captured_count, total_targets], HORIZONTAL_ALIGNMENT_CENTER, 275.0, 19, Color("dbe5ff"))
	_button(BACK_BUTTON, "BACK", Color("8291b9"))
	_button(RESET_BUTTON, "RESET", Color("ffc857"))
	var can_pause := state in [GameState.COUNTDOWN, GameState.PLAYING, GameState.PAUSED]
	_button(PAUSE_BUTTON, "RESUME" if state == GameState.PAUSED else "PAUSE", palette[selected_color_index], can_pause)
	_button(CLOSE_BUTTON, "CLOSE", Color("ff657a"))
	if capture_flash > 0.0:
		draw_rect(Rect2(0.0, 79.0, VIEW_SIZE.x * capture_flash, 3.0), palette[selected_color_index], true)


func _draw_touch_stick() -> void:
	if touch_id == -1 and not mouse_steering:
		return
	var origin := touch_origin
	var knob := touch_position
	draw_circle(origin, 53.0, Color(0.75, 0.82, 1.0, 0.10))
	draw_arc(origin, 53.0, 0.0, TAU, 40, Color(0.75, 0.82, 1.0, 0.30), 2.0, true)
	draw_circle(knob, 23.0, Color(palette[selected_color_index], 0.34))


func _draw_results() -> void:
	draw_rect(Rect2(300.0, 128.0, 680.0, 510.0), Color(0.025, 0.03, 0.12, 0.96), true)
	draw_rect(Rect2(300.0, 128.0, 680.0, 510.0), palette[selected_color_index], false, 4.0)
	_center_text("SOLAR SYSTEM COMPLETE", 220.0, 43, palette[selected_color_index])
	_center_text("Trixie painted every world", 264.0, 20, Color("b9c6e7"))
	_center_text(_format_time(final_time), 375.0, 68, Color.WHITE)
	_center_text("BEST  " + _format_time(best_time), 435.0, 23, Color("ffd777"))
	_button(AGAIN_BUTTON, "RUN AGAIN", palette[selected_color_index])
	_button(MENU_BUTTON, "MENU", Color("8291b9"))
