extends Control

# The cutscene's second beat: a wide establishing shot looking out over
# the world, with the player character's silhouette in the foreground -
# classic "hero overlooking the horizon" framing. Purely procedural.

var stars: Array = []

func _ready() -> void:
	resized.connect(_generate_stars)
	_generate_stars()

func _generate_stars() -> void:
	stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(60):
		stars.append({
			"x": rng.randf_range(0.0, max(size.x, 1.0)),
			"y": rng.randf_range(0.0, max(size.y, 1.0) * 0.55),
			"r": rng.randf_range(0.6, 1.8),
			"phase": rng.randf_range(0.0, TAU),
		})
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	var t: float = Time.get_ticks_msec() * 0.001

	# Sky gradient, dark blue-purple to near black.
	var bands := 14
	for i in range(bands):
		var frac: float = float(i) / float(bands)
		var col: Color = Color(0.06, 0.06, 0.1, 1).lerp(Color(0.01, 0.01, 0.015, 1), frac)
		draw_rect(Rect2(0, h * 0.6 * frac, w, h * 0.6 / bands + 1), col)

	# Twinkling stars.
	for s in stars:
		var tw: float = 0.5 + 0.5 * sin(t * 0.9 + s["phase"])
		draw_circle(Vector2(s["x"], s["y"]), s["r"], Color(0.85, 0.88, 0.95, 0.3 + 0.5 * tw))

	# A dim, hazy moon.
	draw_circle(Vector2(w * 0.72, h * 0.22), 34.0, Color(0.75, 0.72, 0.6, 0.5))
	draw_circle(Vector2(w * 0.72, h * 0.22), 26.0, Color(0.85, 0.82, 0.7, 0.6))

	# Rolling hills / distant ruin silhouette on the horizon.
	var horizon_y: float = h * 0.62
	var hills := PackedVector2Array()
	hills.append(Vector2(0, h))
	var segs := 10
	for i in range(segs + 1):
		var x: float = w * float(i) / float(segs)
		var y: float = horizon_y - sin(float(i) * 1.3 + 2.0) * 26.0 - 10.0
		hills.append(Vector2(x, y))
	hills.append(Vector2(w, h))
	draw_colored_polygon(hills, Color(0.03, 0.03, 0.04, 1))

	# Ground the character stands on.
	draw_rect(Rect2(0, horizon_y, w, h - horizon_y), Color(0.02, 0.02, 0.025, 1))

	# Character silhouette, viewed from behind, standing looking out.
	var cx: float = w * 0.5
	var cy: float = h * 0.86
	var body_col := Color(0.01, 0.01, 0.015, 1)
	draw_circle(Vector2(cx, cy - 62), 13.0, body_col)
	var torso := PackedVector2Array([
		Vector2(cx - 16, cy - 48), Vector2(cx + 16, cy - 48),
		Vector2(cx + 20, cy + 10), Vector2(cx - 20, cy + 10),
	])
	draw_colored_polygon(torso, body_col)
	draw_rect(Rect2(cx - 17, cy + 8, 13, 40), body_col)
	draw_rect(Rect2(cx + 4, cy + 8, 13, 40), body_col)
	# A slung weapon shape across the back for a "raider" read.
	draw_line(Vector2(cx - 14, cy - 44), Vector2(cx + 16, cy - 4), Color(0.015, 0.015, 0.02, 1), 5.0)
