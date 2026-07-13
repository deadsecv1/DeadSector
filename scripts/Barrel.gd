extends Node2D

# A simple rusted barrel decoration - procedural, no image needed. Purely
# visual dressing, same non-blocking approach as Crate.gd.

@export var barrel_radius: float = 16.0
@export var barrel_color: Color = Color(0.32, 0.28, 0.12, 1)

func _draw() -> void:
	draw_circle(Vector2.ZERO, barrel_radius, barrel_color)
	draw_arc(Vector2.ZERO, barrel_radius, 0.0, TAU, 24, Color(0, 0, 0, 0.55), 2.0)
	draw_circle(Vector2.ZERO, barrel_radius * 0.62, Color(0, 0, 0, 0.18))
	draw_line(Vector2(-barrel_radius, -barrel_radius * 0.35), Vector2(barrel_radius, -barrel_radius * 0.35), Color(0, 0, 0, 0.3), 1.5)
	draw_line(Vector2(-barrel_radius, barrel_radius * 0.35), Vector2(barrel_radius, barrel_radius * 0.35), Color(0, 0, 0, 0.3), 1.5)
	draw_line(Vector2(-barrel_radius * 0.5, -barrel_radius * 0.7), Vector2(-barrel_radius * 0.5, barrel_radius * 0.7), Color(1, 1, 1, 0.1), 1.0)
