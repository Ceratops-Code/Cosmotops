class_name ColorPlanet
extends Node2D


var radius := 40.0
var base_color := Color("5f83f2")
var captured_color := Color("41f4c6")
var captured := false
var capture_progress := 0.0
var ringed := false
var style := 0
var seed := 1
var craters: Array[Dictionary] = []
var pulse_time := 0.0
var exploding := false
var explosion_progress := 0.0
var ring_angle := -0.25


func configure(new_radius: float, color: Color, has_rings: bool, new_style: int, new_seed: int) -> void:
	radius = new_radius
	base_color = color
	ringed = has_rings
	style = new_style
	seed = new_seed


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	ring_angle = rng.randf_range(-0.42, 0.32)
	var crater_count := 2 + style
	for index in range(crater_count):
		var angle := rng.randf_range(0.0, TAU)
		var distance := rng.randf_range(radius * 0.12, radius * 0.55)
		craters.append({
			"position": Vector2.from_angle(angle) * distance,
			"radius": rng.randf_range(radius * 0.07, radius * 0.16),
		})
	queue_redraw()


func _process(delta: float) -> void:
	pulse_time += delta
	if captured or exploding:
		queue_redraw()


func capture(color: Color) -> bool:
	if captured or exploding:
		return false
	captured = true
	captured_color = color
	var color_tween := create_tween()
	color_tween.tween_method(_set_capture_progress, 0.0, 1.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var scale_tween := create_tween()
	scale_tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_QUAD)
	scale_tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return true


func explode() -> void:
	if exploding:
		return
	exploding = true
	var tween := create_tween()
	tween.tween_method(_set_explosion_progress, 0.0, 1.0, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


func _set_capture_progress(value: float) -> void:
	capture_progress = value
	queue_redraw()


func _set_explosion_progress(value: float) -> void:
	explosion_progress = value
	queue_redraw()


func _ellipse_points(rx: float, ry: float, from_angle: float, to_angle: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(steps + 1):
		var amount := float(index) / float(steps)
		var angle := lerpf(from_angle, to_angle, amount)
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry).rotated(ring_angle))
	return points


func _draw() -> void:
	if exploding:
		_draw_explosion()
		return

	var color := base_color.lerp(captured_color, capture_progress)
	if captured:
		var glow_alpha := 0.12 + sin(pulse_time * 4.0) * 0.035
		draw_circle(Vector2.ZERO, radius + 10.0, Color(captured_color, glow_alpha))

	if ringed:
		var back_ring := _ellipse_points(radius * 1.62, radius * 0.50, 0.0, TAU, 56)
		draw_polyline(back_ring, color.lightened(0.42), maxf(5.0, radius * 0.16), true)
		draw_polyline(back_ring, Color("2d315f"), maxf(1.5, radius * 0.035), true)

	draw_circle(Vector2(4.0, 7.0), radius + 2.0, Color(0.0, 0.0, 0.12, 0.75))
	draw_circle(Vector2.ZERO, radius, color.darkened(0.12))
	draw_circle(Vector2(-radius * 0.10, -radius * 0.10), radius * 0.91, color)
	draw_circle(Vector2(-radius * 0.27, -radius * 0.31), radius * 0.32, Color(1.0, 1.0, 1.0, 0.11))

	if style % 3 == 1:
		for stripe in range(3):
			var stripe_y := -radius * 0.42 + stripe * radius * 0.40
			draw_arc(Vector2(0.0, stripe_y), radius * (0.78 - absf(stripe_y) / radius * 0.25), 0.20, PI - 0.20, 24, Color(color.darkened(0.22), 0.55), maxf(2.0, radius * 0.07), true)

	for crater in craters:
		var crater_position: Vector2 = crater["position"]
		var crater_radius: float = crater["radius"]
		draw_circle(crater_position, crater_radius, Color(color.darkened(0.30), 0.72))
		draw_circle(crater_position + Vector2(-crater_radius * 0.22, -crater_radius * 0.22), crater_radius * 0.64, Color(color.lightened(0.13), 0.35))

	if ringed:
		var front_ring := _ellipse_points(radius * 1.62, radius * 0.50, 0.0, PI, 28)
		draw_polyline(front_ring, color.lightened(0.48), maxf(5.0, radius * 0.16), true)
		draw_polyline(front_ring, Color("373d70"), maxf(1.5, radius * 0.035), true)


func _draw_explosion() -> void:
	var amount := explosion_progress
	var fire_color := captured_color if captured else base_color
	var fade := 1.0 - amount
	draw_circle(Vector2.ZERO, radius * (0.35 + amount * 1.65), Color("fff2a8") * Color(1.0, 1.0, 1.0, fade))
	draw_circle(Vector2.ZERO, radius * (0.22 + amount * 1.18), Color(fire_color, fade))
	for index in range(14):
		var angle := TAU * float(index) / 14.0 + float(seed % 9) * 0.11
		var direction := Vector2.from_angle(angle)
		var fragment_position := direction * radius * amount * (1.6 + float(index % 3) * 0.22)
		var fragment_size := maxf(1.0, radius * 0.12 * fade)
		draw_circle(fragment_position, fragment_size, Color(fire_color.lightened(0.25), fade))
