extends Control

# Ambient menu vignette: a lone raider walking slowly through misty
# woods, flashlight cone sweeping ahead - a quiet, atmospheric moment
# rather than the skyline's monster prowl. Fully procedural, same
# technique as MainMenuBackground.gd.

var time: float = 0.0
var trees: Array = []  # {x, w, h, depth}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_regenerate)
	_regenerate()
	set_process(true)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _regenerate() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	trees.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var x := -60.0
	while x < w + 60.0:
		var depth: float = rng.randf_range(0.3, 1.0)
		trees.append({
			"x": x, "w": rng.randf_range(18, 42) * depth, "h": rng.randf_range(0.35, 0.62) * h * depth,
			"depth": depth,
		})
		x += rng.randf_range(40, 90)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return

	# Deep green-black gradient sky, darker than the skyline vignette -
	# this one reads as "in the woods at night", not "over the city".
	var top_color := Color(0.03, 0.05, 0.035, 1)
	var bottom_color := Color(0.01, 0.015, 0.012, 1)
	var steps := 24
	for i in range(steps):
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		draw_rect(Rect2(0, h * t0, w, h * (t1 - t0) + 1.5), top_color.lerp(bottom_color, t0))

	# The walking raider - slow, continuous pace across the whole width,
	# looping back to the start once off-screen.
	var walk_speed := 26.0
	var figure_x: float = fmod(time * walk_speed, w + 120.0) - 60.0
	var ground_y := h * 0.82
	var bob: float = abs(sin(time * 4.0)) * 3.0
	var facing := 1.0

	# Flashlight cone, drawn BEFORE the trees pass in front of it so
	# distant trunks read as silhouettes cut into the beam.
	var aim_wobble: float = sin(time * 0.6) * 0.15
	var cone_dir := Vector2(cos(aim_wobble), sin(aim_wobble) * 0.3).normalized() * facing
	var cone_len := 260.0
	var cone_spread := 0.34
	var cone_origin := Vector2(figure_x + 8.0 * facing, ground_y - 34.0 - bob)
	var cone_a := cone_origin + cone_dir.rotated(-cone_spread) * cone_len
	var cone_b := cone_origin + cone_dir.rotated(cone_spread) * cone_len
	var cone_poly := PackedVector2Array([cone_origin, cone_a, cone_b])
	draw_colored_polygon(cone_poly, Color(0.85, 0.9, 0.7, 0.1))
	var cone_a2 := cone_origin + cone_dir.rotated(-cone_spread * 0.5) * cone_len * 0.6
	var cone_b2 := cone_origin + cone_dir.rotated(cone_spread * 0.5) * cone_len * 0.6
	draw_colored_polygon(PackedVector2Array([cone_origin, cone_a2, cone_b2]), Color(0.9, 0.95, 0.8, 0.16))

	# Distant tree silhouettes, darker/smaller the further back.
	for t in trees:
		var tint: float = lerp(0.02, 0.06, t["depth"])
		var col := Color(tint, tint * 1.3, tint, 1)
		var trunk := Rect2(t["x"] - 2.5, h - t["h"], 5.0, t["h"])
		draw_rect(trunk, col)
		var canopy := PackedVector2Array([
			Vector2(t["x"], h - t["h"]),
			Vector2(t["x"] - t["w"] * 0.5, h - t["h"] + t["w"] * 0.55),
			Vector2(t["x"] + t["w"] * 0.5, h - t["h"] + t["w"] * 0.55),
		])
		draw_colored_polygon(canopy, col)

	# The raider figure itself - simple silhouette, walking leg swing.
	var leg_swing: float = sin(time * 8.0) * 8.0
	var body_top := Vector2(figure_x, ground_y - 34.0 - bob)
	var body_bottom := Vector2(figure_x, ground_y - 10.0 - bob)
	var fig_color := Color(0.01, 0.01, 0.01, 0.92)
	draw_line(body_top, body_bottom, fig_color, 5.0)
	draw_circle(body_top + Vector2(0, -6.0), 6.0, fig_color)
	draw_line(body_bottom, body_bottom + Vector2(6.0 + leg_swing, 14.0), fig_color, 4.0)
	draw_line(body_bottom, body_bottom + Vector2(-6.0 - leg_swing, 14.0), fig_color, 4.0)
	draw_line(body_top + Vector2(0, 4.0), body_top + Vector2(12.0 * facing, 10.0), fig_color, 3.5)

	# Drifting ground fog, two bands at different speeds.
	var fog_y := h * 0.75
	var fog_h := h * 0.25
	var drift1: float = fmod(time * 10.0, w + 200.0) - 200.0
	var drift2: float = fmod(-time * 6.0 + 150.0, w + 200.0) - 200.0
	draw_rect(Rect2(drift1, fog_y, w * 0.65, fog_h), Color(0.06, 0.08, 0.06, 0.22))
	draw_rect(Rect2(drift2, fog_y + fog_h * 0.25, w * 0.55, fog_h * 0.75), Color(0.05, 0.07, 0.05, 0.2))

	# A few slow-drifting fireflies/dust motes for life.
	for i in range(10):
		var seed_t: float = time * 0.25 + float(i) * 1.7
		var fx: float = fmod(float(i) * 137.0 + sin(seed_t) * 40.0, w)
		var fy: float = h * 0.55 + sin(seed_t * 1.3 + float(i)) * h * 0.15
		var tw: float = 0.4 + 0.4 * sin(time * 2.0 + float(i) * 2.1)
		draw_circle(Vector2(fx, fy), 1.4, Color(0.75, 0.9, 0.5, 0.25 * tw))

	# Vignette.
	var vig := Color(0, 0, 0, 0.42)
	draw_rect(Rect2(0, 0, w, h * 0.1), vig)
	draw_rect(Rect2(0, h * 0.9, w, h * 0.1), vig)
