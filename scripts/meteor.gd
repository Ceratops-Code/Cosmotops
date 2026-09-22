class_name TargetMeteor
extends Node2D


signal impacted(planet)

var start_position := Vector2.ZERO
var target_position := Vector2.ZERO
var target_planet: Node
var delay := 0.0
var duration := 1.0
var elapsed := 0.0
var curve_offset := 0.0
var previous_position := Vector2.ZERO


func setup(from: Vector2, to: Vector2, wait_time: float, travel_time: float, planet: Node, curve: float) -> void:
	start_position = from
	target_position = to
	delay = wait_time
	duration = travel_time
	target_planet = planet
	curve_offset = curve
	position = from
	previous_position = from
	visible = false


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < delay:
		return
	visible = true
	var amount := clampf((elapsed - delay) / duration, 0.0, 1.0)
	var direction := (target_position - start_position).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var next_position := start_position.lerp(target_position, amount)
	next_position += perpendicular * sin(amount * PI) * curve_offset
	var travel := next_position - previous_position
	position = next_position
	if travel.length_squared() > 0.01:
		rotation = travel.angle() + PI * 0.5
	previous_position = next_position
	if amount >= 1.0:
		impacted.emit(target_planet)
		queue_free()


func _draw() -> void:
	draw_line(Vector2(0.0, 9.0), Vector2(0.0, 52.0), Color(1.0, 0.32, 0.10, 0.0), 13.0)
	draw_line(Vector2(0.0, 7.0), Vector2(0.0, 43.0), Color("ff7738"), 8.0)
	draw_line(Vector2(0.0, 6.0), Vector2(0.0, 31.0), Color("fff0a5"), 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -13.0), Vector2(-10.0, -3.0), Vector2(-8.0, 9.0),
		Vector2(3.0, 12.0), Vector2(11.0, 3.0), Vector2(8.0, -8.0)
	]), Color("6b5975"))
	draw_circle(Vector2(-2.0, -2.0), 3.0, Color("a795aa"))
