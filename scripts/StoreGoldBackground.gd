extends Control

# A calm, mostly-static field of slowly twinkling gold sparkles for the
# Store background - deliberately far less motion than the Spectral
# Tide's drifting soul mist.

var sparkles: Array = []
const SPARKLE_COUNT := 40

func _ready() -> void:
	resized.connect(_init_sparkles)
	_init_sparkles()
	set_process(true)

func _init_sparkles() -> void:
	sparkles.clear()
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	for i in range(SPARKLE_COUNT):
		sparkles.append({
			"x": randf_range(0.0, w), "y": randf_range(0.0, h),
			"r": randf_range(1.0, 2.8), "phase": randf_range(0.0, TAU), "speed": randf_range(0.5, 1.1),
		})

func _process(_delta: float) -> void:
	# Same fix as DystopianBackground.gd - this reskin shares the same
	# always-processing-regardless-of-visible flaw.
	if not is_visible_in_tree():
		return
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.06, 0.03, 1))
	var t := Time.get_ticks_msec() * 0.001
	for sp in sparkles:
		var flicker: float = 0.4 + 0.6 * sin(t * sp["speed"] + sp["phase"])
		draw_circle(Vector2(sp["x"], sp["y"]), sp["r"] * (0.6 + flicker * 0.5), Color(0.9, 0.75, 0.35, 0.2 + flicker * 0.3))
