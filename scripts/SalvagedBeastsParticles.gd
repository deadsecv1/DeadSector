extends Control

# A warm, amber drifting particle field for the Salvaged Beasts panel -
# orange embers drifting slowly upward, matching the event's button and
# progression theming instead of leaving the panel flat and plain.

var particles: Array = []
const PARTICLE_COUNT := 55

func _ready() -> void:
	resized.connect(_init_particles)
	_init_particles()
	set_process(true)

func _init_particles() -> void:
	particles.clear()
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	for i in range(PARTICLE_COUNT):
		particles.append({
			"x": randf_range(0.0, w), "y": randf_range(0.0, h),
			"speed": randf_range(6.0, 16.0), "drift": randf_range(-6.0, 6.0),
			"r": randf_range(0.8, 2.6), "phase": randf_range(0.0, TAU), "bright": randf() < 0.35,
		})

func _process(delta: float) -> void:
	var w: float = max(size.x, 1.0)
	var h: float = max(size.y, 1.0)
	for p in particles:
		p["y"] -= p["speed"] * delta
		p["x"] += p["drift"] * delta * 0.2
		if p["y"] < -10.0:
			p["y"] = h + 10.0
			p["x"] = randf_range(0.0, w)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.035, 0.015, 1))
	var t := Time.get_ticks_msec() * 0.001
	for p in particles:
		var flicker: float = 0.4 + 0.6 * sin(t * 2.0 + p["phase"])
		var col: Color = Color(1.0, 0.75, 0.3, 0.5 * flicker) if p["bright"] else Color(0.85, 0.45, 0.1, 0.35 * flicker)
		draw_circle(Vector2(p["x"], p["y"]), p["r"] * (0.6 + flicker * 0.5), col)
