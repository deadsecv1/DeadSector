extends Control

# A compact, dark HUD readout panel behind the top-left currency
# display, with a handful of slow drifting embers behind the text for
# a bit of life instead of a flat, static box.

var particles: Array = []
const PARTICLE_COUNT := 10

func _ready() -> void:
	resized.connect(_init_particles)
	_init_particles()
	set_process(true)

func _init_particles() -> void:
	particles.clear()
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	for i in range(PARTICLE_COUNT):
		particles.append(_make_particle(w, h, true))

func _make_particle(w: float, h: float, random_x: bool) -> Dictionary:
	return {
		"x": randf_range(0.0, w) if random_x else -6.0,
		"y": randf_range(0.0, h),
		"speed": randf_range(10.0, 22.0),
		"drift": randf_range(-3.0, 3.0),
		"r": randf_range(0.8, 1.8),
		"phase": randf_range(0.0, TAU),
	}

func _process(delta: float) -> void:
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	for p in particles:
		p["x"] += p["speed"] * delta
		p["y"] += p["drift"] * delta * 0.3
		if p["x"] > w + 6.0:
			var fresh := _make_particle(w, h, false)
			p["x"] = fresh["x"]; p["y"] = fresh["y"]; p["speed"] = fresh["speed"]; p["drift"] = fresh["drift"]
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0 or h <= 0:
		return

	var bg := Color(0.05, 0.045, 0.045, 0.85)
	var cut := 10.0
	var pts := PackedVector2Array([
		Vector2(cut, 0), Vector2(w, 0), Vector2(w, h),
		Vector2(0, h), Vector2(0, cut)
	])
	draw_colored_polygon(pts, bg)

	# Faint single-pixel edge, no bright accent color - just enough to
	# separate the panel from the world behind it.
	draw_line(Vector2(cut, 0), Vector2(w, 0), Color(1, 1, 1, 0.08), 1.0)
	draw_line(Vector2(0, h), Vector2(w, h), Color(1, 1, 1, 0.08), 1.0)

	var t := Time.get_ticks_msec() * 0.001
	for p in particles:
		var flicker: float = 0.4 + 0.6 * sin(t * 2.5 + p["phase"])
		draw_circle(Vector2(p["x"], p["y"]), p["r"] * (0.6 + flicker * 0.4), Color(0.85, 0.5, 0.2, 0.35 * flicker))
