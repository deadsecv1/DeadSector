extends Node2D

var start_point: Vector2 = Vector2.ZERO
var end_point: Vector2 = Vector2.ZERO
var _life: float = 0.0
const DURATION := 0.22

func setup(from_pos: Vector2, to_pos: Vector2) -> void:
	start_point = from_pos
	end_point = to_pos
	global_position = Vector2.ZERO
	z_index = 6

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_life += delta
	if _life >= DURATION:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var fade: float = 1.0 - (_life / DURATION)
	var segments := 7
	var pts := PackedVector2Array()
	pts.append(start_point)
	for i in range(1, segments):
		var t: float = float(i) / float(segments)
		var base: Vector2 = start_point.lerp(end_point, t)
		var perp: Vector2 = (end_point - start_point).orthogonal().normalized()
		base += perp * randf_range(-8.0, 8.0)
		pts.append(base)
	pts.append(end_point)
	draw_polyline(pts, Color(0.6, 0.85, 1.0, 0.9 * fade), 2.5)
	draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.6 * fade), 1.0)
	draw_circle(end_point, 6.0 * fade, Color(0.7, 0.9, 1.0, 0.5 * fade))
