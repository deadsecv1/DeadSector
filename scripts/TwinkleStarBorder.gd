extends Control

# Small stars that appear and shine along a Control's border - each one
# fades in, holds briefly at full brightness, then fades out before
# reappearing at a new random spot on the perimeter. Purely decorative,
# ignores mouse input.

@export var star_color: Color = Color(1.0, 0.95, 0.6, 1.0)
@export var star_count: int = 6
@export var min_size: float = 2.5
@export var max_size: float = 5.0
@export var cycle_min: float = 1.1
@export var cycle_max: float = 2.4

var stars: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_reset_stars)
	_reset_stars()
	set_process(true)

func _reset_stars() -> void:
	stars.clear()
	for i in range(star_count):
		var s := _make_star()
		# Stagger initial timers so they don't all twinkle in sync.
		s["timer"] = randf_range(0.0, s["cycle"])
		stars.append(s)

func _make_star() -> Dictionary:
	return {
		"t": randf_range(0.0, 1.0),
		"size": randf_range(min_size, max_size),
		"cycle": randf_range(cycle_min, cycle_max),
		"timer": 0.0,
	}

# Walks fractional distance t (0..1) around the rectangle's perimeter,
# starting at the top-left corner, clockwise.
func _perimeter_point(t: float, w: float, h: float) -> Vector2:
	var perim: float = 2.0 * (w + h)
	var d: float = fposmod(t, 1.0) * perim
	if d < w:
		return Vector2(d, 0.0)
	d -= w
	if d < h:
		return Vector2(w, d)
	d -= h
	if d < w:
		return Vector2(w - d, h)
	d -= w
	return Vector2(0.0, h - d)

func _process(delta: float) -> void:
	for star in stars:
		star["timer"] += delta
		if star["timer"] >= star["cycle"]:
			star["timer"] = 0.0
			star["t"] = randf_range(0.0, 1.0)
			star["cycle"] = randf_range(cycle_min, cycle_max)
			star["size"] = randf_range(min_size, max_size)
	queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	for star in stars:
		var progress: float = star["timer"] / star["cycle"]
		# Twinkle envelope: quick fade in, brief hold at full brightness,
		# slower fade out.
		var alpha: float
		if progress < 0.25:
			alpha = progress / 0.25
		elif progress < 0.55:
			alpha = 1.0
		else:
			alpha = 1.0 - (progress - 0.55) / 0.45
		alpha = clamp(alpha, 0.0, 1.0)
		var pos: Vector2 = _perimeter_point(star["t"], w, h)
		_draw_star(pos, star["size"], Color(star_color.r, star_color.g, star_color.b, star_color.a * alpha))

# A simple 4-point sparkle: a cross, a smaller diagonal cross, and a
# bright center dot - reads clearly as a "twinkling star" at small sizes.
func _draw_star(center: Vector2, r: float, col: Color) -> void:
	draw_line(center + Vector2(-r, 0.0), center + Vector2(r, 0.0), col, 1.2, true)
	draw_line(center + Vector2(0.0, -r), center + Vector2(0.0, r), col, 1.2, true)
	var r2 := r * 0.45
	draw_line(center + Vector2(-r2, -r2), center + Vector2(r2, r2), col, 1.0, true)
	draw_line(center + Vector2(-r2, r2), center + Vector2(r2, -r2), col, 1.0, true)
	draw_circle(center, r * 0.28, col)
