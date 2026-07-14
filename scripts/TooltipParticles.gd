extends Control

# Drifting sparkle background for item tooltips. Exotic/Multiversal
# items get noticeably more particles and a shimmer pass, so the best
# gear in the game visibly stands out even before you read the name.

var particle_color: Color = Color(0.8, 0.8, 0.8, 1)
var gradient_colors: Array = []
var intensity: int = 8
var particles: Array = []

func _ready() -> void:
	resized.connect(_init_particles)
	_init_particles()
	set_process(true)

func _init_particles() -> void:
	particles.clear()
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	for i in range(intensity):
		particles.append({
			"x": randf_range(0.0, w), "y": randf_range(0.0, h),
			"r": randf_range(0.8, 2.2), "phase": randf_range(0.0, TAU),
			"drift": randf_range(-6.0, 6.0), "speed": randf_range(0.6, 1.4),
		})

func _process(delta: float) -> void:
	# Same fix as DystopianBackground.gd: Godot doesn't skip _process() for
	# an invisible node on its own. Global Chat can retain up to 60 message
	# rows, each with its own TooltipParticles instance if a chat background
	# is equipped - without this check, all of them keep animating and
	# redrawing for the rest of the session even after the chat panel (the
	# actual thing that toggles visible/hidden) is closed.
	if not is_visible_in_tree():
		return
	for p in particles:
		p["y"] -= p["speed"] * 6.0 * delta
		if p["y"] < 0.0:
			p["y"] = size.y
			p["x"] = randf_range(0.0, max(size.x, 1.0))
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in range(particles.size()):
		var p = particles[i]
		var flicker: float = 0.4 + 0.6 * sin(t * 2.5 + p["phase"])
		var col: Color = particle_color
		if gradient_colors.size() > 0:
			col = gradient_colors[i % gradient_colors.size()]
		draw_circle(Vector2(p["x"], p["y"]), p["r"] * (0.6 + flicker * 0.5), Color(col.r, col.g, col.b, 0.35 + flicker * 0.35))
