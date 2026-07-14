extends Control

# Paints an animated, moody industrial-sector skyline for the Main Menu:
# gradient sky, twinkling stars, a silhouetted skyline with flickering
# window lights, drifting fog, scattered warning beacons, and a vignette.
# Everything is procedural (no image files) and redrawn every frame so
# lights flicker and fog drifts instead of sitting static.

var rng := RandomNumberGenerator.new()
var time := 0.0

var star_timer: float = 0.0
var star_interval: float = 4.0
var star_active: bool = false
var star_progress: float = 0.0
var star_start: Vector2 = Vector2.ZERO
var star_end: Vector2 = Vector2.ZERO

var buildings: Array = []     # {x, w, h, jagged}
var near_buildings: Array = []
var windows: Array = []       # {x, y, w, h, phase, speed}
var stars: Array = []         # {x, y, r, phase}
var beacons: Array = []       # {x, y, warm, phase}

var _lagged_cursor_x: float = 0.0
var _cursor_lag_ready: bool = false
const MONSTER_CURSOR_LAG := 3.2

func _ready() -> void:
	resized.connect(_regenerate)
	_regenerate()

func _process(delta: float) -> void:
	time += delta
	var mouse_x := get_global_mouse_position().x
	if not _cursor_lag_ready:
		_lagged_cursor_x = mouse_x
		_cursor_lag_ready = true
	else:
		_lagged_cursor_x = lerp(_lagged_cursor_x, mouse_x, clamp(delta / MONSTER_CURSOR_LAG, 0.0, 1.0))
	star_timer += delta
	if not star_active and star_timer >= star_interval:
		_trigger_star()
	if star_active:
		star_progress += delta / 2.8
		if star_progress >= 1.0:
			star_active = false
			star_timer = 0.0
			star_interval = randf_range(5.0, 12.0)
	queue_redraw()

func _trigger_star() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return
	star_active = true
	star_progress = 0.0
	star_start = Vector2(randf_range(w * 0.05, w * 0.55), randf_range(h * 0.04, h * 0.2))
	star_end = star_start + Vector2(randf_range(420.0, 650.0), randf_range(160.0, 300.0))

func _regenerate() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return

	buildings.clear()
	near_buildings.clear()
	windows.clear()
	stars.clear()
	beacons.clear()

	rng.seed = 1337
	var x := 0.0
	while x < w:
		var bw: float = rng.randf_range(40, 130)
		var bh: float = rng.randf_range(0.14, 0.46) * h
		buildings.append({"x": x, "w": bw, "h": bh, "jagged": rng.randf() < 0.4})
		# scatter a few windows on this building
		var win_count: int = rng.randi_range(2, 6)
		for i in range(win_count):
			windows.append({
				"x": x + rng.randf_range(6, max(bw - 6, 7)),
				"y": h - bh + rng.randf_range(6, max(bh - 6, 7)),
				"w": 4.0, "h": 6.0,
				"phase": rng.randf_range(0, TAU),
				"speed": rng.randf_range(0.3, 1.2),
			})
		x += bw + rng.randf_range(6, 26)

	rng.seed = 4242
	x = -40.0
	while x < w:
		var bw2: float = rng.randf_range(60, 160)
		var bh2: float = rng.randf_range(0.08, 0.22) * h
		near_buildings.append({"x": x, "w": bw2, "h": bh2})
		x += bw2 + rng.randf_range(20, 60)

	rng.seed = 7
	for i in range(60):
		stars.append({
			"x": rng.randf_range(0, w), "y": rng.randf_range(0, h * 0.55),
			"r": rng.randf_range(0.6, 1.6), "phase": rng.randf_range(0, TAU),
		})

	rng.seed = 99
	for i in range(16):
		beacons.append({
			"x": rng.randf_range(0, w), "y": rng.randf_range(h * 0.4, h * 0.86),
			"warm": rng.randf() < 0.7, "phase": rng.randf_range(0, TAU),
		})

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return

	var top_color := Color(0.07, 0.09, 0.11, 1)
	var bottom_color := Color(0.015, 0.02, 0.025, 1)
	var steps := 28
	for i in range(steps):
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		draw_rect(Rect2(0, h * t0, w, h * (t1 - t0) + 1.5), top_color.lerp(bottom_color, t0))

	# Twinkling stars.
	for s in stars:
		var tw := 0.5 + 0.5 * sin(time * 0.8 + s["phase"])
		draw_circle(Vector2(s["x"], s["y"]), s["r"], Color(0.8, 0.85, 0.95, 0.35 + 0.4 * tw))

	# A shooting star every several seconds - a bright streak with a
	# fading trail, muted warm-white to fit the dystopian palette rather
	# than a cheery rainbow sparkle.
	if star_active:
		var pos: Vector2 = star_start.lerp(star_end, star_progress)
		var dir: Vector2 = (star_end - star_start).normalized()
		var tail: Vector2 = pos - dir * 130.0
		var fade: float = sin(PI * clamp(star_progress, 0.0, 1.0))
		draw_line(tail, pos, Color(0.95, 0.85, 0.7, 0.95 * fade), 2.5)
		draw_line(tail, tail.lerp(pos, 0.55), Color(0.95, 0.85, 0.7, 0.4 * fade), 1.3)
		draw_circle(pos, 3.2, Color(1.0, 0.97, 0.9, fade))
		draw_circle(pos, 6.5, Color(1.0, 0.9, 0.75, fade * 0.3))

	# Far skyline with flickering windows.
	var building_color := Color(0.025, 0.03, 0.04, 1)
	for b in buildings:
		draw_rect(Rect2(b["x"], h - b["h"], b["w"], b["h"]), building_color)
		if b["jagged"]:
			var jag := PackedVector2Array([
				Vector2(b["x"], h - b["h"]), Vector2(b["x"] + b["w"] * 0.4, h - b["h"] - 20),
				Vector2(b["x"] + b["w"] * 0.7, h - b["h"]), Vector2(b["x"] + b["w"], h - b["h"])
			])
			draw_colored_polygon(jag, building_color)

	for win in windows:
		var flicker := 0.5 + 0.5 * sin(time * win["speed"] + win["phase"])
		if flicker > 0.55:
			draw_rect(Rect2(win["x"], win["y"], win["w"], win["h"]), Color(0.95, 0.75, 0.35, 0.55 * flicker))

	# Closer, lighter skyline layer for depth.
	var near_color := Color(0.045, 0.05, 0.06, 1)
	for b in near_buildings:
		draw_rect(Rect2(b["x"], h - b["h"], b["w"], b["h"]), near_color)

	# A large shadowy creature prowling along the rooftops - dark but
	# clearly visible now, with a jagged spine, a distinct head/jaw, claws,
	# and a tail, so it reads as an actual monster rather than a blob.
	# Stalks toward the (heavily lagged) cursor's horizontal position
	# instead of pacing a fixed loop - unsettling on purpose.
	var monster_w := 170.0
	var monster_x: float = clamp(_lagged_cursor_x, -monster_w * 0.3, w + monster_w * 0.3)
	var monster_ground := h * 0.6
	var bob: float = sin(time * 2.2) * 3.0
	var monster_color := Color(0.03, 0.03, 0.035, 0.78)
	var rim_color := Color(0.6, 0.15, 0.12, 0.35)

	var body := PackedVector2Array([
		Vector2(monster_x - monster_w * 0.12, monster_ground + bob),
		Vector2(monster_x + monster_w * 0.05, monster_ground - monster_w * 0.16 + bob),
		Vector2(monster_x + monster_w * 0.18, monster_ground - monster_w * 0.3 + bob),
		Vector2(monster_x + monster_w * 0.3, monster_ground - monster_w * 0.24 + bob),
		Vector2(monster_x + monster_w * 0.42, monster_ground - monster_w * 0.4 + bob),
		Vector2(monster_x + monster_w * 0.55, monster_ground - monster_w * 0.34 + bob),
		Vector2(monster_x + monster_w * 0.7, monster_ground - monster_w * 0.46 + bob),
		Vector2(monster_x + monster_w * 0.86, monster_ground - monster_w * 0.3 + bob),
		Vector2(monster_x + monster_w * 1.02, monster_ground - monster_w * 0.22 + bob),
		Vector2(monster_x + monster_w * 1.12, monster_ground - monster_w * 0.06 + bob),
		Vector2(monster_x + monster_w * 1.08, monster_ground + bob),
		Vector2(monster_x + monster_w * 0.9, monster_ground + bob),
		Vector2(monster_x + monster_w * 0.75, monster_ground + monster_w * 0.08 + bob),
		Vector2(monster_x + monster_w * 0.6, monster_ground + bob),
		Vector2(monster_x + monster_w * 0.3, monster_ground + monster_w * 0.06 + bob),
		Vector2(monster_x + monster_w * 0.1, monster_ground + bob),
	])
	draw_colored_polygon(body, monster_color)

	# Tail trailing behind.
	var tail_shape := PackedVector2Array([
		Vector2(monster_x - monster_w * 0.12, monster_ground - monster_w * 0.05 + bob),
		Vector2(monster_x - monster_w * 0.38, monster_ground - monster_w * 0.16 + bob),
		Vector2(monster_x - monster_w * 0.32, monster_ground + bob),
	])
	draw_colored_polygon(tail_shape, monster_color)

	# Head/jaw at the front.
	var head := PackedVector2Array([
		Vector2(monster_x + monster_w * 1.02, monster_ground - monster_w * 0.22 + bob),
		Vector2(monster_x + monster_w * 1.22, monster_ground - monster_w * 0.2 + bob),
		Vector2(monster_x + monster_w * 1.26, monster_ground - monster_w * 0.08 + bob),
		Vector2(monster_x + monster_w * 1.1, monster_ground - monster_w * 0.02 + bob),
	])
	draw_colored_polygon(head, monster_color)

	# Jagged spine spikes along the back.
	for i in range(5):
		var t: float = 0.28 + float(i) * 0.13
		var base := Vector2(monster_x + monster_w * t, monster_ground - monster_w * (0.3 + 0.14 * sin(t * 6.0)) + bob)
		var tip := base + Vector2(2.0, -monster_w * 0.14)
		var spike := PackedVector2Array([base + Vector2(-6, 0), tip, base + Vector2(6, 0)])
		draw_colored_polygon(spike, monster_color)

	# Clawed feet.
	var leg_phase: float = sin(time * 3.0)
	for lx in [0.18, 0.42, 0.68, 0.92]:
		var foot := Vector2(monster_x + monster_w * lx, monster_ground + bob) + Vector2(leg_phase * 6.0 * (1.0 if int(lx * 10) % 2 == 0 else -1.0), 14.0)
		draw_line(Vector2(monster_x + monster_w * lx, monster_ground + bob), foot, monster_color, 6.0)
		draw_line(foot, foot + Vector2(-5, 4), monster_color, 3.0)
		draw_line(foot, foot + Vector2(5, 4), monster_color, 3.0)

	# Subtle warm rim-light along the back edge for menace.
	draw_line(Vector2(monster_x + monster_w * 0.3, monster_ground - monster_w * 0.24 + bob), Vector2(monster_x + monster_w * 0.7, monster_ground - monster_w * 0.46 + bob), rim_color, 1.5)

	var eye_glow: float = 0.55 + 0.35 * sin(time * 5.0)
	draw_circle(Vector2(monster_x + monster_w * 1.12, monster_ground - monster_w * 0.15 + bob), 2.6, Color(0.9, 0.2, 0.15, eye_glow))
	draw_circle(Vector2(monster_x + monster_w * 1.12, monster_ground - monster_w * 0.15 + bob), 5.0, Color(0.9, 0.2, 0.15, eye_glow * 0.25))

	# Drifting ground fog (two semi-transparent bands moving at different speeds).
	var fog_y := h * 0.72
	var fog_h := h * 0.28
	var drift1: float = fmod(time * 14.0, w + 200.0) - 200.0
	var drift2: float = fmod(-time * 9.0 + 150.0, w + 200.0) - 200.0
	draw_rect(Rect2(drift1, fog_y, w * 0.6, fog_h), Color(0.08, 0.09, 0.1, 0.18))
	draw_rect(Rect2(drift2, fog_y + fog_h * 0.2, w * 0.5, fog_h * 0.8), Color(0.06, 0.07, 0.08, 0.16))

	# Scattered warning beacons that pulse.
	for bcn in beacons:
		var glow := 0.35 + 0.4 * (0.5 + 0.5 * sin(time * 1.4 + bcn["phase"]))
		var col: Color = Color(0.9, 0.28, 0.12, glow) if bcn["warm"] else Color(0.6, 0.75, 0.85, glow * 0.6)
		draw_circle(Vector2(bcn["x"], bcn["y"]), 2.2, col)
		draw_circle(Vector2(bcn["x"], bcn["y"]), 6.0, Color(col.r, col.g, col.b, glow * 0.15))

	# Vignette.
	var vignette := Color(0, 0, 0, 0.4)
	draw_rect(Rect2(0, 0, w, h * 0.1), vignette)
	draw_rect(Rect2(0, h * 0.9, w, h * 0.1), vignette)
