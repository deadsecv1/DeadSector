extends Node2D

# A small hunger bar drawn directly below the HealthBar (#55 food half) -
# same industrial bar-above-the-head language, but warm amber/brown tones
# throughout so it never reads as a second health bar at a glance.

var current: int = 100
var max_val: int = 100

const WIDTH := 36.0
const HEIGHT := 5.0
const Y_OFFSET := -24.0

func update_hunger(cur: int, mx: int) -> void:
	current = cur
	max_val = max(mx, 1)
	queue_redraw()

func _draw() -> void:
	var pct: float = clamp(float(current) / float(max_val), 0.0, 1.0)
	var top_left := Vector2(-WIDTH / 2.0, Y_OFFSET)

	draw_rect(Rect2(top_left, Vector2(WIDTH, HEIGHT)), Color(0, 0, 0, 0.65))

	# Deliberately clear of HealthBar's red/amber/green palette at every
	# tier (its mid-tier amber used to be pixel-identical to this bar's
	# full-tier color) - a burnt-orange/rust family instead, so the two
	# bars never render as the same color 5px apart.
	var fill_color: Color
	if pct < 0.3:
		fill_color = Color(0.55, 0.18, 0.08, 1)
	elif pct < 0.6:
		fill_color = Color(0.78, 0.38, 0.08, 1)
	else:
		fill_color = Color(0.9, 0.55, 0.12, 1)
	if pct > 0.0:
		draw_rect(Rect2(top_left, Vector2(WIDTH * pct, HEIGHT)), fill_color)

	draw_rect(Rect2(top_left, Vector2(WIDTH, HEIGHT)), Color(0, 0, 0, 0.9), false, 1.0)
