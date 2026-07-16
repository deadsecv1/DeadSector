extends Control

# A minimal line chart - no existing chart-drawing precedent anywhere in
# this codebase (checked), so this is a small purpose-built one rather
# than a generic reusable component. Plots carried-loot value over the
# course of a raid from GameManager.last_raid_breakdown.value_samples.

var samples: Array = []  # [{"time": float, "value": int}, ...]

const LINE_COLOR := Color(0.95, 0.85, 0.4, 1)
const FILL_COLOR := Color(0.95, 0.85, 0.4, 0.18)
const AXIS_COLOR := Color(1, 1, 1, 0.25)
const MARGIN_LEFT := 46.0
const MARGIN_BOTTOM := 20.0
const MARGIN_TOP := 10.0
const MARGIN_RIGHT := 10.0

func set_samples(new_samples: Array) -> void:
	samples = new_samples
	queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= MARGIN_LEFT + MARGIN_RIGHT or h <= MARGIN_TOP + MARGIN_BOTTOM:
		return
	var plot_w: float = w - MARGIN_LEFT - MARGIN_RIGHT
	var plot_h: float = h - MARGIN_TOP - MARGIN_BOTTOM
	var origin := Vector2(MARGIN_LEFT, MARGIN_TOP + plot_h)

	# Axis lines.
	draw_line(origin, origin + Vector2(plot_w, 0), AXIS_COLOR, 1.0)
	draw_line(origin, origin - Vector2(0, plot_h), AXIS_COLOR, 1.0)

	if samples.size() < 2:
		var empty_lbl := "Not enough data from this raid to graph."
		draw_string(ThemeDB.fallback_font, Vector2(MARGIN_LEFT, MARGIN_TOP + plot_h / 2.0), empty_lbl, HORIZONTAL_ALIGNMENT_LEFT, plot_w, 13, Color(1, 1, 1, 0.6))
		return

	var max_time: float = 0.001
	var max_value: float = 1.0
	for s in samples:
		max_time = max(max_time, float(s.get("time", 0.0)))
		max_value = max(max_value, float(s.get("value", 0)))

	var points := PackedVector2Array()
	for s in samples:
		var t: float = float(s.get("time", 0.0)) / max_time
		var v: float = float(s.get("value", 0)) / max_value
		points.append(origin + Vector2(t * plot_w, -v * plot_h))

	# Filled area under the line for a "graph" read at a glance, then the
	# crisp line itself on top.
	var fill_points := PackedVector2Array()
	fill_points.append(origin)
	for p in points:
		fill_points.append(p)
	fill_points.append(Vector2(points[points.size() - 1].x, origin.y))
	draw_colored_polygon(fill_points, FILL_COLOR)
	draw_polyline(points, LINE_COLOR, 2.5, true)
	for p in points:
		draw_circle(p, 3.0, LINE_COLOR)

	# Axis labels: peak value on the y-axis, total elapsed time on the x-axis.
	draw_string(ThemeDB.fallback_font, Vector2(2, MARGIN_TOP + 4), "%d" % int(max_value), HORIZONTAL_ALIGNMENT_LEFT, MARGIN_LEFT - 4, 11, Color(1, 1, 1, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(2, origin.y + 4), "0", HORIZONTAL_ALIGNMENT_LEFT, MARGIN_LEFT - 4, 11, Color(1, 1, 1, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(origin.x, origin.y + 4), "0:00", HORIZONTAL_ALIGNMENT_LEFT, 40, 11, Color(1, 1, 1, 0.6))
	var minutes := int(max_time) / 60
	var seconds := int(max_time) % 60
	draw_string(ThemeDB.fallback_font, Vector2(origin.x + plot_w - 50, origin.y + 4), "%d:%02d" % [minutes, seconds], HORIZONTAL_ALIGNMENT_RIGHT, 50, 11, Color(1, 1, 1, 0.6))
