extends Control

# Slow-drifting, glowing soul-mist wisps for the Battle Pass background -
# green/blue ghostly particles, purely procedural.

var wisps: Array = []
const WISP_COUNT := 35

func _ready() -> void:
	resized.connect(_init_wisps)
	_init_wisps()
	set_process(true)

func _init_wisps() -> void:
	wisps.clear()
	for i in range(WISP_COUNT):
		wisps.append(_make_wisp())

func _make_wisp() -> Dictionary:
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	return {
		"x": randf_range(0.0, w), "y": randf_range(0.0, h),
		"drift_x": randf_range(-8.0, 8.0), "drift_y": randf_range(-10.0, -3.0),
		"r": randf_range(2.0, 6.0), "phase": randf_range(0.0, TAU),
		"hue": randf() < 0.5,
	}

func _process(delta: float) -> void:
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	for wisp in wisps:
		wisp["x"] += wisp["drift_x"] * delta
		wisp["y"] += wisp["drift_y"] * delta
		if wisp["y"] < -10.0:
			wisp["y"] = h + 10.0
			wisp["x"] = randf_range(0.0, w)
		if wisp["x"] < -10.0:
			wisp["x"] = w + 10.0
		elif wisp["x"] > w + 10.0:
			wisp["x"] = -10.0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.06, 0.06, 1))
	var t := Time.get_ticks_msec() * 0.001
	for wisp in wisps:
		var flicker: float = 0.5 + 0.5 * sin(t * 1.6 + wisp["phase"])
		var col: Color = Color(0.3, 0.85, 0.7, 0.25 + flicker * 0.35) if wisp["hue"] else Color(0.35, 0.55, 0.95, 0.25 + flicker * 0.35)
		draw_circle(Vector2(wisp["x"], wisp["y"]), wisp["r"] * (0.7 + flicker * 0.5), col)
