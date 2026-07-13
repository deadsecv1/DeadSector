extends Control

# A simpler version of the Play button's comet-trail border trace,
# scaled down for a smaller secondary button - a bright amber line
# continuously loops around the outline so it reads as "there's
# something worth claiming here" even without hovering. Sits as a
# transparent overlay child on top of the button, so it doesn't
# disturb whatever hover script the button itself already has.

const TRACE_COLOR := Color(1.0, 0.8, 0.35, 1.0)
const TRACE_SPEED := 70.0
const TRACE_SEGMENTS := 16
const TRACE_SEGMENT_GAP := 5.0

func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

# Walks distance `d` along the button's outline starting at the
# top-left corner, going clockwise - lets the trail move continuously
# around all 4 edges without hand-tracking which edge it's currently on.
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
	var perim: float = 2.0 * (w + h)
	var head: float = fmod(Time.get_ticks_msec() * 0.001 * TRACE_SPEED, perim)
	var prev := _perimeter_point(head, w, h)
	for i in range(1, TRACE_SEGMENTS + 1):
		var d: float = head - i * TRACE_SEGMENT_GAP
		var pt := _perimeter_point(d, w, h)
		var alpha: float = (1.0 - float(i) / float(TRACE_SEGMENTS)) * 0.85
		draw_line(prev, pt, Color(TRACE_COLOR.r, TRACE_COLOR.g, TRACE_COLOR.b, alpha), 2.0, true)
		prev = pt
