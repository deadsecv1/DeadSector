extends Node2D

# A simple wooden crate decoration - procedural, no image needed.

@export var box_size: float = 30.0
@export var box_color: Color = Color(0.32, 0.22, 0.13, 1)

func _draw() -> void:
	var h := box_size / 2.0
	draw_rect(Rect2(-h, -h, box_size, box_size), box_color)
	draw_rect(Rect2(-h, -h, box_size, box_size), Color(0, 0, 0, 0.5), false, 2.0)
	draw_line(Vector2(-h, 0), Vector2(h, 0), Color(0, 0, 0, 0.3), 1.5)
	draw_line(Vector2(0, -h), Vector2(0, h), Color(0, 0, 0, 0.3), 1.5)
	draw_line(Vector2(-h, -h), Vector2(h, h), Color(1, 1, 1, 0.08), 1.0)
