class_name TrixieShip
extends Node2D


const TRIXIE_REGION := Rect2(529.0, 100.0, 654.0, 611.0)
const SHIP_TEXTURES := [
	preload("res://assets/ship_arrow.png"),
	preload("res://assets/ship_dart.png"),
	preload("res://assets/ship_nova.png"),
	preload("res://assets/ship_saucer.png"),
]
const COCKPIT_OFFSETS := [Vector2(0.0, -4.0), Vector2(0.0, -4.0), Vector2(0.0, 2.0), Vector2.ZERO]

var ship_color := Color("41f4c6")
var ship_style := 0
var velocity := Vector2.ZERO
var max_speed := 330.0
var acceleration := 980.0
var braking := 760.0
var hit_radius := 29.0
var movement_bounds := Rect2(32.0, 92.0, 1216.0, 594.0)
var thrust_amount := 0.0
var trixie_texture: Texture2D = preload("res://assets/trixie.png")


func configure(color: Color, bounds: Rect2, style_index := 0) -> void:
	ship_color = color
	movement_bounds = bounds
	ship_style = clampi(style_index, 0, SHIP_TEXTURES.size() - 1)
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
	var texture: Texture2D = SHIP_TEXTURES[ship_style]
	var source_size := texture.get_size()
	var target_height := 78.0 if ship_style == 3 else 76.0
	var target_size := source_size * (target_height / source_size.y)
	var target_rect := Rect2(-target_size * 0.5, target_size)

	var flame_wave := 4.0 + sin(Time.get_ticks_msec() * 0.022) * 3.0
	if thrust_amount > 0.08:
		var flame_length := 18.0 + flame_wave * thrust_amount
		var flame_width := 8.0 if ship_style == 3 else 11.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-flame_width, target_size.y * 0.40),
			Vector2(0.0, target_size.y * 0.40 + flame_length),
			Vector2(flame_width, target_size.y * 0.40),
		]), Color("ff873b"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-flame_width * 0.45, target_size.y * 0.39),
			Vector2(0.0, target_size.y * 0.38 + flame_length * 0.62),
			Vector2(flame_width * 0.45, target_size.y * 0.39),
		]), Color("fff4a4"))

	# The selected paint color remains readable without recoloring Kenney's detailed sprite art.
	draw_circle(Vector2.ZERO, maxf(target_size.x, target_size.y) * 0.48, Color(ship_color, 0.12))
	draw_texture_rect(texture, Rect2(target_rect.position + Vector2(4.0, 6.0), target_rect.size), false, Color(0.0, 0.0, 0.05, 0.62))
	draw_texture_rect(texture, target_rect, false, Color.WHITE)

	var cockpit: Vector2 = COCKPIT_OFFSETS[ship_style]
	var cockpit_radius := 15.0 if ship_style == 3 else 13.0
	draw_circle(cockpit, cockpit_radius + 3.5, Color(0.01, 0.02, 0.09, 0.92))
	draw_circle(cockpit, cockpit_radius + 1.5, ship_color)
	draw_circle(cockpit, cockpit_radius, Color("79d9ff"))
	draw_texture_rect_region(
		trixie_texture,
		Rect2(cockpit - Vector2(11.0, 11.0), Vector2(22.0, 21.0)),
		TRIXIE_REGION,
		Color.WHITE
	)
	draw_arc(cockpit, cockpit_radius + 1.0, PI, TAU, 24, Color(1.0, 1.0, 1.0, 0.72), 2.2, true)
	draw_arc(Vector2.ZERO, maxf(target_size.x, target_size.y) * 0.48, -0.15, PI + 0.15, 38, Color(ship_color, 0.76), 2.0, true)
