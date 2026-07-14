extends Control

# A small looping animated banner for the Leaderboard header - a gold
# 3-place podium silhouette with a slowly bobbing star over 1st place
# and embers drifting upward, distinct from both UpdateHeroBanner's
# scanline sweep and the Skill Tree's circuit pulses. No external art.

@export var gold_color: Color = Color(0.9, 0.75, 0.3, 1)

var _time: float = 0.0
var _embers: Array = []

func _ready() -> void:
	set_process(true)
	for i in range(14):
		_embers.append({
			"x": randf_range(0.0, 1.0), "y": randf_range(0.0, 1.0),
			"speed": randf_range(6.0, 14.0), "phase": randf_range(0.0, TAU),
		})

func _process(delta: float) -> void:
	_time += delta
	for e in _embers:
		e["y"] -= delta * e["speed"] * 0.01
		if e["y"] < -0.05:
			e["y"] = 1.05
			e["x"] = randf_range(0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.06, 0.03, 1))

	for e in _embers:
		var flicker: float = 0.5 + 0.5 * sin(_time * 3.0 + e["phase"])
		draw_circle(Vector2(e["x"] * w, e["y"] * h), 1.6, Color(gold_color.r, gold_color.g, gold_color.b, 0.25 + flicker * 0.35))

	# Three podium bars, centered, 2nd-1st-3rd left to right like a real podium.
	var base_y: float = h * 0.92
	var bar_w: float = w * 0.09
	var gap: float = w * 0.03
	var heights := [0.42, 0.62, 0.3]
	var cx: float = w / 2.0
	var xs := [cx - bar_w - gap, cx - bar_w * 0.5, cx + bar_w + gap * 2.0]
	for i in range(3):
		var bh: float = h * heights[i]
		var alpha: float = 0.5 if i == 1 else 0.32
		draw_rect(Rect2(xs[i], base_y - bh, bar_w, bh), Color(gold_color.r, gold_color.g, gold_color.b, alpha))
		draw_rect(Rect2(xs[i], base_y - bh, bar_w, bh), Color(gold_color.r, gold_color.g, gold_color.b, 0.7), false, 1.0)

	# A gently bobbing star over 1st place.
	var star_x: float = xs[1] + bar_w * 0.5
	var star_y: float = base_y - h * heights[1] - 14.0 + sin(_time * 1.8) * 3.0
	var pulse: float = 0.7 + 0.3 * sin(_time * 2.4)
	draw_circle(Vector2(star_x, star_y), 3.0, Color(gold_color.r, gold_color.g, gold_color.b, 0.9))
	draw_circle(Vector2(star_x, star_y), 8.0 * pulse, Color(gold_color.r, gold_color.g, gold_color.b, 0.18 * pulse))
