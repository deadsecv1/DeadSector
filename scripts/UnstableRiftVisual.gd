extends Node2D

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
	draw_circle(Vector2.ZERO, 44.0, Color(0.05, 0.02, 0.08, 0.5))
	var crack := PackedVector2Array([
		Vector2(0, -30), Vector2(6, -10), Vector2(-4, -2), Vector2(8, 8),
		Vector2(-2, 18), Vector2(4, 30), Vector2(-4, 18), Vector2(-10, 6),
		Vector2(2, -4), Vector2(-8, -14),
	])
	draw_polyline(crack, Color(0.85, 0.5, 1.0, 0.7 + pulse * 0.3), 2.5)
	for i in range(8):
		var ang: float = (TAU / 8.0) * i + t * 0.3
		var r: float = 20.0 + pulse * 8.0
		var pos := Vector2(cos(ang), sin(ang)) * r
		draw_circle(pos, 2.0 + pulse * 1.5, Color(0.7, 0.35, 0.95, 0.3 * pulse))
