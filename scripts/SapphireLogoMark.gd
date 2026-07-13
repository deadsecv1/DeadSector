extends Control

# The Sapphire Signal Studio mark: a faceted gem falls from off-screen
# above, cracks and shatters on impact, and reveals a bright signal
# light that was inside it - which is also what lights the studio name
# up out of near-darkness (see StudioSplash.gd, which listens for the
# `shattered` signal to time the name reveal against the actual light,
# not a fixed guessed delay).

signal shattered

enum Phase { FALLING, IMPACT, SETTLED }

const DEEP_BLUE := Color(0.05, 0.14, 0.5, 1.0)
const MID_BLUE := Color(0.12, 0.35, 0.85, 1.0)
const BRIGHT_BLUE := Color(0.45, 0.75, 1.0, 1.0)
const HIGHLIGHT := Color(0.8, 0.92, 1.0, 1.0)
const SIGNAL_COLOR := Color(0.65, 0.88, 1.0, 1.0)

const FALL_DURATION := 1.05
const IMPACT_DURATION := 0.3
const FALL_START_OFFSET := -420.0

var phase: int = Phase.FALLING
var phase_time: float = 0.0
var _time: float = 0.0

var shards: Array = []  # {pos, vel, rot, rot_speed, size, alpha}
var _flash_alpha: float = 0.0
var _rings: Array = []
var _ring_timer: float = 0.0
const RING_INTERVAL := 1.1
const RING_LIFETIME := 1.8

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	phase_time += delta
	match phase:
		Phase.FALLING:
			pass
		Phase.IMPACT:
			_flash_alpha = max(0.0, _flash_alpha - delta * 3.2)
			for s in shards:
				s["pos"] += s["vel"] * delta
				s["vel"] += Vector2(0, 480.0) * delta
				s["rot"] += s["rot_speed"] * delta
				s["alpha"] = max(0.0, s["alpha"] - delta * 1.35)
			if phase_time >= IMPACT_DURATION:
				phase = Phase.SETTLED
				phase_time = 0.0
		Phase.SETTLED:
			_ring_timer += delta
			if _ring_timer >= RING_INTERVAL:
				_ring_timer = 0.0
				_rings.append({"age": 0.0})
			for r in _rings:
				r["age"] += delta
			_rings = _rings.filter(func(r): return r["age"] < RING_LIFETIME)
	queue_redraw()

func _ease_in(t: float) -> float:
	return t * t

func _gem_facet_points(center: Vector2, gem_r: float) -> Dictionary:
	var top := center + Vector2(0, -gem_r)
	var bottom := center + Vector2(0, gem_r * 0.85)
	var band_r: float = gem_r * 0.62
	var band_y: float = center.y - gem_r * 0.15
	var upper: Array = []
	for i in range(6):
		var ang: float = -PI / 2.0 + TAU * float(i) / 6.0
		upper.append(Vector2(center.x + cos(ang) * band_r, band_y + sin(ang) * band_r * 0.55))
	return {"top": top, "bottom": bottom, "upper": upper}

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var rest_center := Vector2(w / 2.0, h / 2.0)
	var gem_r: float = min(w, h) * 0.34

	if phase == Phase.FALLING:
		var t: float = clamp(phase_time / FALL_DURATION, 0.0, 1.0)
		var eased: float = _ease_in(t)
		var y_offset: float = lerp(FALL_START_OFFSET, 0.0, eased)
		var center := rest_center + Vector2(0, y_offset)
		var spin: float = lerp(0.0, TAU * 0.35, t)
		_draw_gem(center, gem_r, spin, 1.0)
		return

	if phase == Phase.IMPACT:
		if _flash_alpha > 0.0:
			draw_circle(rest_center, gem_r * 2.2, Color(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, _flash_alpha * 0.5))
		for s in shards:
			if s["alpha"] <= 0.0:
				continue
			var tri := PackedVector2Array([
				s["pos"] + Vector2(0, -s["size"]).rotated(s["rot"]),
				s["pos"] + Vector2(s["size"] * 0.6, s["size"] * 0.5).rotated(s["rot"]),
				s["pos"] + Vector2(-s["size"] * 0.6, s["size"] * 0.5).rotated(s["rot"]),
			])
			draw_colored_polygon(tri, Color(MID_BLUE.r, MID_BLUE.g, MID_BLUE.b, s["alpha"]))
		_draw_signal(rest_center, gem_r, 0.4)
		return

	# SETTLED: the crystal is gone - just the exposed signal light, its
	# ping rings, and a slow ambient shimmer.
	_draw_signal(rest_center, gem_r, 1.0)
	for r in _rings:
		var rt: float = r["age"] / RING_LIFETIME
		var ring_r: float = gem_r * 0.5 + rt * gem_r * 2.4
		var alpha: float = (1.0 - rt) * 0.5
		draw_arc(rest_center, ring_r, 0.0, TAU, 48, Color(SIGNAL_COLOR.r, SIGNAL_COLOR.g, SIGNAL_COLOR.b, alpha), 1.6, true)

func _draw_gem(center: Vector2, gem_r: float, spin: float, alpha: float) -> void:
	var pts := _gem_facet_points(center, gem_r)
	var top: Vector2 = pts["top"]
	var bottom: Vector2 = pts["bottom"]
	var upper: Array = pts["upper"]
	var shimmer: float = 0.5 + 0.5 * sin(_time * 1.6 + spin)

	for i in range(6):
		var a: Vector2 = upper[i]
		var b: Vector2 = upper[(i + 1) % 6]
		var facet := PackedVector2Array([top, a, b])
		var shade: float = 0.35 + 0.4 * ((i % 2) as float) + 0.15 * shimmer * (1.0 if i % 3 == 0 else 0.0)
		draw_colored_polygon(facet, _a(DEEP_BLUE.lerp(BRIGHT_BLUE, clamp(shade, 0.0, 1.0)), alpha))
	for i in range(6):
		var a2: Vector2 = upper[i]
		var b2: Vector2 = upper[(i + 1) % 6]
		var facet2 := PackedVector2Array([bottom, a2, b2])
		var shade2: float = 0.2 + 0.3 * (((i + 1) % 2) as float)
		draw_colored_polygon(facet2, _a(DEEP_BLUE.lerp(MID_BLUE, clamp(shade2, 0.0, 1.0)), alpha))
	for i in range(6):
		draw_line(top, upper[i], _a(HIGHLIGHT, 0.5 * alpha), 1.0)
		draw_line(bottom, upper[i], _a(DEEP_BLUE, 0.6 * alpha), 1.0)
	for i in range(6):
		draw_line(upper[i], upper[(i + 1) % 6], _a(HIGHLIGHT, 0.4 * alpha), 1.0)

func _draw_signal(center: Vector2, gem_r: float, strength: float) -> void:
	var pulse: float = 0.75 + 0.25 * sin(_time * 3.2)
	for i in range(4):
		var glow_r: float = gem_r * (0.14 + float(i) * 0.15) * strength
		draw_circle(center, glow_r, _a(SIGNAL_COLOR, 0.08 * strength * pulse))
	draw_circle(center, gem_r * 0.08 * strength, _a(Color(1, 1, 1, 1), 0.9 * strength))
	draw_circle(center, gem_r * 0.15 * strength, _a(SIGNAL_COLOR, 0.5 * strength * pulse))

func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, alpha)

# Called by StudioSplash.gd once the fall duration has elapsed - kicks
# off the impact/shatter and emits `shattered` for the parent to sync
# the name reveal against.
func trigger_impact() -> void:
	if phase != Phase.FALLING:
		return
	phase = Phase.IMPACT
	phase_time = 0.0
	_flash_alpha = 1.0
	shards.clear()
	var w: float = size.x
	var h: float = size.y
	var center := Vector2(w / 2.0, h / 2.0)
	for i in range(9):
		var ang: float = randf_range(0.0, TAU)
		var speed: float = randf_range(80.0, 220.0)
		shards.append({
			"pos": center, "vel": Vector2(cos(ang), sin(ang) - 0.4) * speed,
			"rot": randf_range(0.0, TAU), "rot_speed": randf_range(-6.0, 6.0),
			"size": randf_range(5.0, 12.0), "alpha": 1.0,
		})
	shattered.emit()

func is_settled() -> bool:
	return phase == Phase.SETTLED
