extends Control

# Ambient menu vignette: the extraction chopper, rotor spinning, search
# beam sweeping the ground, dust kicked up below it - the "moment of
# extraction" this whole game is built around. Fully procedural, same
# technique as MainMenuBackground.gd.

var time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return

	# Dark sky with a faint warm glow low on the horizon - an extraction
	# zone lit up, not just empty night.
	var top_color := Color(0.02, 0.025, 0.04, 1)
	var horizon_color := Color(0.1, 0.06, 0.04, 1)
	var bottom_color := Color(0.015, 0.015, 0.02, 1)
	var steps := 24
	for i in range(steps):
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var c: Color
		if t0 < 0.65:
			c = top_color.lerp(horizon_color, t0 / 0.65)
		else:
			c = horizon_color.lerp(bottom_color, (t0 - 0.65) / 0.35)
		draw_rect(Rect2(0, h * t0, w, h * (t1 - t0) + 1.5), c)

	# Chopper hovers with a slow bob, drifting very slightly side to
	# side, roughly centered-upper in frame.
	var hover_y: float = h * 0.32 + sin(time * 0.7) * 8.0
	var drift_x: float = w * 0.5 + sin(time * 0.18) * w * 0.08
	var body_color := Color(0.02, 0.02, 0.025, 0.95)

	# Ground fog/dust kicked up beneath the rotor wash.
	var dust_y := h * 0.86
	var dust_drift: float = fmod(time * 18.0, w + 200.0) - 200.0
	draw_rect(Rect2(dust_drift, dust_y, w * 0.5, h * 0.14), Color(0.35, 0.3, 0.22, 0.1))
	draw_rect(Rect2(drift_x - 140.0, dust_y - 6.0, 280.0, h * 0.12), Color(0.4, 0.34, 0.24, 0.14))

	# Search beam sweeping down and to the side, cutting through the dust.
	var beam_angle: float = sin(time * 0.5) * 0.5 - 1.4
	var beam_len := h * 0.65
	var beam_origin := Vector2(drift_x, hover_y + 14.0)
	var beam_dir := Vector2(cos(beam_angle), sin(beam_angle))
	var beam_a := beam_origin + beam_dir.rotated(-0.09) * beam_len
	var beam_b := beam_origin + beam_dir.rotated(0.09) * beam_len
	draw_colored_polygon(PackedVector2Array([beam_origin, beam_a, beam_b]), Color(0.9, 0.88, 0.7, 0.09))

	# Body: a simple elongated fuselage with a tail boom.
	var fuselage := PackedVector2Array([
		Vector2(drift_x - 46.0, hover_y),
		Vector2(drift_x - 30.0, hover_y - 14.0),
		Vector2(drift_x + 20.0, hover_y - 14.0),
		Vector2(drift_x + 34.0, hover_y - 6.0),
		Vector2(drift_x + 34.0, hover_y + 6.0),
		Vector2(drift_x - 30.0, hover_y + 12.0),
	])
	draw_colored_polygon(fuselage, body_color)
	# Tail boom trailing back.
	draw_line(Vector2(drift_x + 30.0, hover_y), Vector2(drift_x + 90.0, hover_y - 10.0), body_color, 7.0)
	# Tail fin.
	var fin := PackedVector2Array([
		Vector2(drift_x + 84.0, hover_y - 22.0), Vector2(drift_x + 96.0, hover_y - 10.0), Vector2(drift_x + 80.0, hover_y - 4.0),
	])
	draw_colored_polygon(fin, body_color)
	# Landing skids.
	draw_line(Vector2(drift_x - 34.0, hover_y + 16.0), Vector2(drift_x + 20.0, hover_y + 16.0), body_color, 3.0)

	# Main rotor - spins fast, drawn as a thin blurred ellipse rather
	# than distinct blades (reads better at speed than trying to
	# animate individual blade positions).
	var rotor_spin: float = time * 26.0
	var rotor_center := Vector2(drift_x - 6.0, hover_y - 16.0)
	for i in range(2):
		var ang: float = rotor_spin + float(i) * PI
		var tip: Vector2 = rotor_center + Vector2(cos(ang), sin(ang) * 0.18) * 62.0
		draw_line(rotor_center, tip, Color(0.02, 0.02, 0.02, 0.5), 2.0)
	draw_circle(rotor_center, 46.0, Color(0.05, 0.05, 0.05, 0.06))
	# Tail rotor, small and fast.
	var tail_rotor_center := Vector2(drift_x + 92.0, hover_y - 12.0)
	draw_circle(tail_rotor_center, 9.0, Color(0.05, 0.05, 0.05, 0.15))

	# Blinking nav lights - red port, green starboard, white strobe.
	var strobe: float = 1.0 if fmod(time, 1.4) < 0.08 else 0.0
	draw_circle(Vector2(drift_x - 44.0, hover_y + 2.0), 2.0, Color(0.9, 0.15, 0.1, 0.8))
	draw_circle(Vector2(drift_x + 30.0, hover_y - 2.0), 2.0, Color(0.15, 0.85, 0.2, 0.8))
	draw_circle(Vector2(drift_x - 6.0, hover_y - 20.0), 2.6, Color(1, 1, 1, strobe))
	if strobe > 0.0:
		draw_circle(Vector2(drift_x - 6.0, hover_y - 20.0), 7.0, Color(1, 1, 1, 0.25))

	# Distant tree line silhouette along the bottom for scale/grounding.
	var rng := RandomNumberGenerator.new()
	rng.seed = 88
	var x := 0.0
	while x < w:
		var tw2: float = rng.randf_range(20, 50)
		var th: float = rng.randf_range(0.05, 0.12) * h
		draw_rect(Rect2(x, h - th, tw2, th), Color(0.01, 0.012, 0.01, 1))
		x += tw2 + rng.randf_range(4, 16)

	# Vignette.
	var vig := Color(0, 0, 0, 0.42)
	draw_rect(Rect2(0, 0, w, h * 0.1), vig)
	draw_rect(Rect2(0, h * 0.9, w, h * 0.1), vig)
