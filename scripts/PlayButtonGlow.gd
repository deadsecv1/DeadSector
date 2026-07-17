extends Button

# The Play button - the one button on the Main Menu that should feel like
# the obvious next move. Same hover treatment as the other menu buttons
# (scale bounce, glow, orbiting sparkles on hover), PLUS a bright line
# that continuously traces around the button's outline, looping forever -
# a constant "click me" signal even before the mouse ever gets near it.

var hovering: bool = false
var sparkles: Array = []
const SPARKLE_COUNT := 14

const TRACE_COLOR := Color(1.0, 0.42, 0.24, 1.0)
const TRACE_SPEED := 90.0 # pixels per second along the perimeter
const TRACE_SEGMENTS := 22 # comet-tail sample count
const TRACE_SEGMENT_GAP := 6.0 # pixels between trail samples

@onready var glow: ColorRect = $Glow

func _ready() -> void:
	# Deferred rather than read synchronously here - PlayButton is a
	# VBoxContainer child, which only gets its real size from the
	# container's own deferred layout pass, not necessarily resolved yet
	# at _ready() time. A stale (0,0)-based pivot scaled the hover bounce
	# from the wrong corner instead of the button's actual center.
	# resized.connect() alone wasn't enough - it only self-corrects AFTER
	# a wrong value was already visible.
	var set_pivot := func(): pivot_offset = size / 2.0
	set_pivot.call_deferred()
	resized.connect(set_pivot)
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	glow.color = Color(0.03, 0.03, 0.03, 0.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(SPARKLE_COUNT):
		sparkles.append(_make_sparkle())
	set_process(true)

func _make_sparkle() -> Dictionary:
	return {
		"ang": randf_range(0.0, TAU), "dist": randf_range(0.55, 1.3),
		"speed": randf_range(0.3, 0.8), "phase": randf_range(0.0, TAU), "r": randf_range(1.2, 2.6),
	}

func _on_hover_start() -> void:
	hovering = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", 0.55, 0.25)

func _on_hover_end() -> void:
	hovering = false
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_QUAD)
	var gtw := create_tween()
	gtw.tween_property(glow, "color:a", 0.0, 0.3)

func _process(_delta: float) -> void:
	queue_redraw()

# Walks a distance `d` around the button's rectangular outline (starting
# at the top-left corner, going clockwise) and returns the matching point.
# Lets the trace effect below treat the border as one continuous loop
# instead of hand-tracking which of the 4 edges it's currently on.
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
	# --- Idle sparkles, same treatment as the other menu buttons ---
	if hovering:
		var t := Time.get_ticks_msec() * 0.001
		var center := size / 2.0
		var radius: float = size.x * 0.5
		for sp in sparkles:
			var ang: float = sp["ang"] + t * sp["speed"]
			var d: float = radius * sp["dist"]
			var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * d
			var flicker: float = 0.4 + 0.6 * sin(t * 3.0 + sp["phase"])
			draw_circle(pos, sp["r"] * flicker, Color(0.03, 0.03, 0.03, 0.6 * flicker))

	# --- Tracing border: a comet-tail line looping around the outline ---
	var w: float = size.x
	var h: float = size.y
	var perim: float = 2.0 * (w + h)
	var head: float = fmod(Time.get_ticks_msec() * 0.001 * TRACE_SPEED, perim)
	var prev := _perimeter_point(head, w, h)
	for i in range(1, TRACE_SEGMENTS + 1):
		var d: float = head - i * TRACE_SEGMENT_GAP
		var pt := _perimeter_point(d, w, h)
		var alpha: float = (1.0 - float(i) / float(TRACE_SEGMENTS)) * 0.9
		draw_line(prev, pt, Color(TRACE_COLOR.r, TRACE_COLOR.g, TRACE_COLOR.b, alpha), 2.0, true)
		prev = pt
