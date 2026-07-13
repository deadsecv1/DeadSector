extends Node2D

# A small health bar drawn above the character's head in world space, so
# health is read at-a-glance without needing a HUD element. Industrial
# color-coded fill: green -> amber -> red as health drops.

var current: int = 100
var max_val: int = 100

const WIDTH := 36.0
const HEIGHT := 5.0
const Y_OFFSET := -34.0

func update_health(cur: int, mx: int) -> void:
	current = cur
	max_val = max(mx, 1)
	queue_redraw()

func _draw() -> void:
	var pct: float = clamp(float(current) / float(max_val), 0.0, 1.0)
	var top_left := Vector2(-WIDTH / 2.0, Y_OFFSET)

	draw_rect(Rect2(top_left, Vector2(WIDTH, HEIGHT)), Color(0, 0, 0, 0.65))

	var fill_color: Color
	if pct < 0.3:
		fill_color = Color(0.85, 0.2, 0.15, 1)
	elif pct < 0.6:
		fill_color = Color(0.85, 0.65, 0.15, 1)
	else:
		fill_color = Color(0.3, 0.8, 0.35, 1)
	if pct > 0.0:
		draw_rect(Rect2(top_left, Vector2(WIDTH * pct, HEIGHT)), fill_color)

	draw_rect(Rect2(top_left, Vector2(WIDTH, HEIGHT)), Color(0, 0, 0, 0.9), false, 1.0)
