extends Control

# A row of dark building silhouettes along the bottom of the screen -
# same technique as the Main Menu background - now with a slow parallax
# drift and a prowling monster silhouette so the cutscene has real
# motion, not just a static skyline.

var buildings: Array = []
var scroll_x: float = 0.0

# The background this sits over cycles between near-black and light
# grey (see IntroCutscene.gd's _color_cycle_time) - IntroCutscene pushes
# its current text_color here every frame, since that's already
# computed as whichever shade contrasts with the CURRENT background.
# The monster's fill/outline used to be a fixed near-black regardless
# of that cycle, which made it read fine against the light end but
# all but vanish into the dark end - only the small eye-glow dot stayed
# visible, which is what "I can only see his head" was actually seeing.
var contrast_color: Color = Color(0.85, 0.85, 0.9, 1.0)

func _ready() -> void:
	resized.connect(_generate)
	_generate()
	set_process(true)

func _generate() -> void:
	buildings.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 314
	var w: float = max(size.x, 1.0) * 2.2
	var x := 0.0
	while x < w:
		var bw: float = rng.randf_range(50.0, 130.0)
		var bh: float = rng.randf_range(60.0, 220.0)
		buildings.append({"x": x, "w": bw, "h": bh})
		x += bw + rng.randf_range(2.0, 10.0)
	queue_redraw()

func _process(delta: float) -> void:
	scroll_x -= delta * 10.0
	var wrap_w: float = max(size.x, 1.0) * 2.2
	if scroll_x < -wrap_w:
		scroll_x += wrap_w
	queue_redraw()

func _draw() -> void:
	var h: float = size.y
	var w: float = max(size.x, 1.0)
	var wrap_w: float = w * 2.2
	for b in buildings:
		var bx: float = fmod(b["x"] + scroll_x, wrap_w)
		if bx < -150.0:
			bx += wrap_w
		draw_rect(Rect2(bx, h - b["h"], b["w"], b["h"]), Color(0.02, 0.02, 0.025, 1))

	# A prowling monster silhouette crossing the rooftops - same detailed
	# shape as the Main Menu background (tail, jaw, spine spikes, clawed
	# feet), not just a smooth 6-point blob. That was the real issue
	# behind "I can only see his head" - the old shape had no tail, no
	# legs, no jaw, nothing that actually reads as a creature once
	# you're not staring right at the eye-glow dot; it was just a plain
	# rounded hump. Fill/outline are still derived from contrast_color
	# so it stays visible across the whole background cycle instead of
	# the Main Menu version's fixed near-black (which only works there
	# because that background never cycles to a matching dark shade).
	var t: float = Time.get_ticks_msec() * 0.001
	var mw: float = 150.0
	var mx: float = fmod(t * 24.0, w + mw * 2.0) - mw
	var mg: float = h * 0.72
	var bob: float = sin(t * 2.2) * 3.0
	var mc := Color(contrast_color.r * 0.35, contrast_color.g * 0.35, contrast_color.b * 0.35, 0.9)
	var rim := Color(contrast_color.r, contrast_color.g, contrast_color.b, 0.4)

	var body := PackedVector2Array([
		Vector2(mx - mw * 0.12, mg + bob), Vector2(mx + mw * 0.05, mg - mw * 0.16 + bob),
		Vector2(mx + mw * 0.18, mg - mw * 0.3 + bob), Vector2(mx + mw * 0.3, mg - mw * 0.24 + bob),
		Vector2(mx + mw * 0.42, mg - mw * 0.4 + bob), Vector2(mx + mw * 0.55, mg - mw * 0.34 + bob),
		Vector2(mx + mw * 0.7, mg - mw * 0.46 + bob), Vector2(mx + mw * 0.86, mg - mw * 0.3 + bob),
		Vector2(mx + mw * 1.02, mg - mw * 0.22 + bob), Vector2(mx + mw * 1.12, mg - mw * 0.06 + bob),
		Vector2(mx + mw * 1.08, mg + bob), Vector2(mx + mw * 0.9, mg + bob),
		Vector2(mx + mw * 0.75, mg + mw * 0.08 + bob), Vector2(mx + mw * 0.6, mg + bob),
		Vector2(mx + mw * 0.3, mg + mw * 0.06 + bob), Vector2(mx + mw * 0.1, mg + bob),
	])
	draw_colored_polygon(body, mc)

	# Tail trailing behind.
	var tail_shape := PackedVector2Array([
		Vector2(mx - mw * 0.12, mg - mw * 0.05 + bob), Vector2(mx - mw * 0.38, mg - mw * 0.16 + bob),
		Vector2(mx - mw * 0.32, mg + bob),
	])
	draw_colored_polygon(tail_shape, mc)

	# Head/jaw at the front.
	var head := PackedVector2Array([
		Vector2(mx + mw * 1.02, mg - mw * 0.22 + bob), Vector2(mx + mw * 1.22, mg - mw * 0.2 + bob),
		Vector2(mx + mw * 1.26, mg - mw * 0.08 + bob), Vector2(mx + mw * 1.1, mg - mw * 0.02 + bob),
	])
	draw_colored_polygon(head, mc)

	# Jagged spine spikes along the back.
	for i in range(5):
		var st: float = 0.28 + float(i) * 0.13
		var base := Vector2(mx + mw * st, mg - mw * (0.3 + 0.14 * sin(st * 6.0)) + bob)
		var tip := base + Vector2(2.0, -mw * 0.14)
		var spike := PackedVector2Array([base + Vector2(-6, 0), tip, base + Vector2(6, 0)])
		draw_colored_polygon(spike, mc)

	# Clawed feet.
	var leg_phase: float = sin(t * 3.0)
	for lx in [0.18, 0.42, 0.68, 0.92]:
		var foot := Vector2(mx + mw * lx, mg + bob) + Vector2(leg_phase * 6.0 * (1.0 if int(lx * 10) % 2 == 0 else -1.0), 14.0)
		draw_line(Vector2(mx + mw * lx, mg + bob), foot, mc, 6.0)
		draw_line(foot, foot + Vector2(-5, 4), mc, 3.0)
		draw_line(foot, foot + Vector2(5, 4), mc, 3.0)

	# Rim light along the back edge for menace, plus a crisp full
	# outline so the silhouette reads clearly even at the point in the
	# cycle where contrast_color is closest to the fill.
	draw_line(Vector2(mx + mw * 0.3, mg - mw * 0.24 + bob), Vector2(mx + mw * 0.7, mg - mw * 0.46 + bob), rim, 1.5)
	draw_polyline(body + PackedVector2Array([body[0]]), Color(contrast_color.r, contrast_color.g, contrast_color.b, 0.6), 1.5, true)

	var eye_glow: float = 0.55 + 0.35 * sin(t * 5.0)
	draw_circle(Vector2(mx + mw * 1.12, mg - mw * 0.15 + bob), 2.6, Color(0.9, 0.2, 0.15, eye_glow))
	draw_circle(Vector2(mx + mw * 1.12, mg - mw * 0.15 + bob), 5.0, Color(0.9, 0.2, 0.15, eye_glow * 0.25))

# The current on-screen rooftop rects, in this control's local space
# (which lines up with the rest of the scene, since Skyline is anchored
# full-screen with no extra transform) - used by the meteor shower for
# real collision against the buildings, not just the title text.
func get_building_rects() -> Array:
	var h: float = size.y
	var w: float = max(size.x, 1.0)
	var wrap_w: float = w * 2.2
	var rects: Array = []
	for b in buildings:
		var bx: float = fmod(b["x"] + scroll_x, wrap_w)
		if bx < -150.0:
			bx += wrap_w
		if bx < w and bx + b["w"] > 0.0:
			rects.append(Rect2(bx, h - b["h"], b["w"], b["h"]))
	return rects
