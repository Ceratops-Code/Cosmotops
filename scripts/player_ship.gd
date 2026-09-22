class_name TrixieShip
extends Node2D


const TRIXIE_REGION := Rect2(529.0, 100.0, 654.0, 611.0)

var ship_color := Color("41f4c6")
var velocity := Vector2.ZERO
var max_speed := 330.0
var acceleration := 980.0
var braking := 760.0
var hit_radius := 25.0
var movement_bounds := Rect2(32.0, 92.0, 1216.0, 594.0)
var thrust_amount := 0.0
var trixie_texture: Texture2D = preload("res://assets/trixie.png")


func configure(color: Color, bounds: Rect2) -> void:
	ship_color = color
	movement_bounds = bounds
	queue_redraw()


func move_ship(input_vector: Vector2, delta: float) -> void:
	var desired_velocity := input_vector.limit_length(1.0) * max_speed
	var rate := acceleration if input_vector.length_squared() > 0.01 else braking
	velocity = velocity.move_toward(desired_velocity, rate * delta)
	position += velocity * delta
	position.x = clampf(position.x, movement_bounds.position.x, movement_bounds.end.x)
	position.y = clampf(position.y, movement_bounds.position.y, movement_bounds.end.y)
	if input_vector.length_squared() > 0.04:
		var desired_rotation := input_vector.angle() + PI * 0.5
		rotation = lerp_angle(rotation, desired_rotation, minf(1.0, delta * 11.0))
	thrust_amount = move_toward(thrust_amount, input_vector.length(), delta * 5.0)
	queue_redraw()


func stop() -> void:
	velocity = Vector2.ZERO
	thrust_amount = 0.0
	queue_redraw()


func _draw() -> void:
	var flame_wave := 4.0 + sin(Time.get_ticks_msec() * 0.022) * 3.0
	if thrust_amount > 0.08:
		var flame_length := 20.0 + flame_wave * thrust_amount
		draw_colored_polygon(PackedVector2Array([
			Vector2(-10.0, 31.0), Vector2(0.0, 31.0 + flame_length), Vector2(10.0, 31.0)
		]), Color("ff873b"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-5.0, 30.0), Vector2(0.0, 39.0 + flame_length * 0.52), Vector2(5.0, 30.0)
		]), Color("fff4a4"))

	draw_colored_polygon(PackedVector2Array([
		Vector2(-7.0, -39.0), Vector2(-38.0, 29.0), Vector2(-13.0, 22.0),
		Vector2(0.0, 34.0), Vector2(13.0, 22.0), Vector2(38.0, 29.0), Vector2(7.0, -39.0)
	]), Color(0.0, 0.0, 0.08, 0.72))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -43.0), Vector2(-35.0, 25.0), Vector2(-12.0, 19.0),
		Vector2(0.0, 32.0), Vector2(12.0, 19.0), Vector2(35.0, 25.0)
	]), ship_color.darkened(0.20))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -39.0), Vector2(-18.0, 18.0), Vector2(0.0, 27.0), Vector2(18.0, 18.0)
	]), ship_color)
	draw_polyline(PackedVector2Array([
		Vector2(0.0, -39.0), Vector2(-35.0, 25.0), Vector2(-12.0, 19.0),
		Vector2(0.0, 32.0), Vector2(12.0, 19.0), Vector2(35.0, 25.0), Vector2(0.0, -39.0)
	]), Color("e9f7ff"), 2.4, true)

	draw_circle(Vector2(0.0, -5.0), 18.5, Color("15203b"))
	draw_circle(Vector2(0.0, -7.0), 15.5, Color("7edcff"))
	draw_texture_rect_region(trixie_texture, Rect2(-15.5, -20.5, 31.0, 29.0), TRIXIE_REGION, Color.WHITE)
	draw_arc(Vector2(0.0, -5.0), 18.5, PI, TAU, 22, Color(1.0, 1.0, 1.0, 0.62), 2.2, true)
