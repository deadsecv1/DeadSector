extends Control

# A small comet-trail line that continuously traces a Control's outline -
# same perimeter-walking technique as AlphaRewardsButtonGlow.gd/
# PlayButtonGlow.gd, just generalized with an exported color/speed so it
# can be reused anywhere a "tracing glow" is wanted, not just one button.

@export var trace_color: Color = Color(1.0, 0.8, 0.35, 1.0)
@export var trace_speed: float = 55.0
@export var trace_segments: int = 12
@export var trace_segment_gap: float = 4.0
@export var trace_width: float = 1.5
# Off (0.0) by default so every existing usage looks exactly as before -
# set above 0 for a wider, softer halo drawn behind the crisp line, for
# spots that specifically want a stronger glow (like the title screen).
@export var glow_boost: float = 0.0
# Empty by default (uses the flat trace_color above, unchanged for every
# existing usage) - set 2+ colors here to have the trace continuously
# cycle through them instead of a single fixed color.
@export var cycle_colors: Array = []
@export var cycle_speed: float = 0.5

func _current_color() -> Color:
	if cycle_colors.size() < 2:
		return trace_color
	var t: float = fmod(Time.get_ticks_msec() * 0.001 * cycle_speed, 1.0) * float(cycle_colors.size())
	var idx: int = int(t) % cycle_colors.size()
	var next_idx: int = (idx + 1) % cycle_colors.size()
	var frac: float = t - floor(t)
	var a: Color = cycle_colors[idx]
	var b: Color = cycle_colors[next_idx]
	return Color(lerp(a.r, b.r, frac), lerp(a.g, b.g, frac), lerp(a.b, b.b, frac), lerp(a.a, b.a, frac))

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

# Walks distance `d` along the outline starting at the top-left corner,
# going clockwise - lets the trail move continuously around all 4 edges
# without hand-tracking which edge it's currently on.
func _perimeter_point(d: float, w: float, h: float) -> Vector2:
	var perim: float = 2.0 * (w + h)
	d = fposmod(d, perim)
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

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var perim: float = 2.0 * (w + h)
	var head: float = fmod(Time.get_ticks_msec() * 0.001 * trace_speed, perim)
	var prev := _perimeter_point(head, w, h)
	var prev_glow := prev
	var col: Color = _current_color()
	for i in range(1, trace_segments + 1):
		var d: float = head - i * trace_segment_gap
		var pt := _perimeter_point(d, w, h)
		var alpha: float = (1.0 - float(i) / float(trace_segments)) * 0.85 * col.a
		if glow_boost > 0.0:
			draw_line(prev_glow, pt, Color(col.r, col.g, col.b, alpha * 0.35), trace_width * (2.0 + glow_boost * 3.0), true)
			prev_glow = pt
		draw_line(prev, pt, Color(col.r, col.g, col.b, alpha), trace_width, true)
		prev = pt
