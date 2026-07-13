extends Control

# A mysterious hooded figure in black, with a dark glow radiating off
# him. His "mouth" (a small horizontal slit, since his face is mostly
# lost in shadow under the hood) shifts subtly while text is being
# typed out, reading as if he's the one speaking the lore.

var talking: bool = false
var _talk_phase: float = 0.0

func _ready() -> void:
	resized.connect(queue_redraw)
	set_process(true)

func set_talking(value: bool) -> void:
	talking = value

func _process(delta: float) -> void:
	if talking:
		_talk_phase += delta * 14.0
	queue_redraw()

func _p(nx: float, ny: float) -> Vector2:
	return Vector2(nx, ny) * size

func _draw() -> void:
	var w: float = size.x
	if w <= 0.0:
		return
	var t := Time.get_ticks_msec() * 0.001

	# The dark glow - a soft pulsing black-purple aura behind him. Made
	# noticeably stronger than before, since it's the main thing that
	# used to separate his silhouette from the equally-dark background.
	var glow_pulse: float = 0.5 + 0.5 * sin(t * 1.2)
	for i in range(3):
		var r: float = w * (0.42 + i * 0.1)
		draw_circle(_p(0.5, 0.55), r, Color(0.35, 0.12, 0.5, 0.14 + glow_pulse * 0.08))

	# Cloak/robe - a wide, floor-length triangular silhouette. Lightened
	# from near-pure-black (which was almost exactly the scene's
	# background color, making him nearly invisible) to a dark but
	# clearly distinct charcoal-purple, so the shape actually reads
	# against the backdrop instead of disappearing into it.
	var cloak := PackedVector2Array([
		_p(0.5, 0.22), _p(0.72, 0.4), _p(0.85, 0.95), _p(0.15, 0.95), _p(0.28, 0.4),
	])
	draw_colored_polygon(cloak, Color(0.13, 0.1, 0.16, 1))
	# Stronger rim light along one edge so the silhouette has real
	# separation and doesn't read as a flat blob.
	draw_line(_p(0.72, 0.4), _p(0.85, 0.95), Color(0.55, 0.3, 0.7, 0.85), 3.0)
	draw_line(_p(0.28, 0.4), _p(0.15, 0.95), Color(0.4, 0.22, 0.55, 0.5), 2.0)

	# Hood - an oval shadow where a face would be, deep enough that
	# only a hint of two eye-glints and the mouth slit are visible.
	draw_circle(_p(0.5, 0.28), w * 0.13, Color(0.06, 0.05, 0.08, 1))
	var hood_shape := PackedVector2Array([
		_p(0.36, 0.24), _p(0.5, 0.14), _p(0.64, 0.24), _p(0.6, 0.4), _p(0.4, 0.4),
	])
	draw_colored_polygon(hood_shape, Color(0.1, 0.08, 0.13, 1))
	draw_polyline(hood_shape + PackedVector2Array([hood_shape[0]]), Color(0.5, 0.3, 0.65, 0.4), 1.5)

	# Faint glowing eyes - brightened slightly so they read clearly as
	# the focal point of the (now visible) silhouette.
	var eye_glow: float = 0.55 + 0.35 * sin(t * 0.8)
	draw_circle(_p(0.455, 0.29), w * 0.014, Color(0.7, 0.35, 0.9, eye_glow))
	draw_circle(_p(0.545, 0.29), w * 0.014, Color(0.7, 0.35, 0.9, eye_glow))

	# Mouth - a small slit that widens slightly while "talking".
	var mouth_open: float = (0.5 + 0.5 * sin(_talk_phase)) if talking else 0.0
	var mouth_w: float = w * (0.03 + mouth_open * 0.015)
	draw_rect(Rect2(_p(0.5, 0.335) - Vector2(mouth_w * 0.5, 0), Vector2(mouth_w, w * (0.006 + mouth_open * 0.01))), Color(0.65, 0.25, 0.8, 0.9))
