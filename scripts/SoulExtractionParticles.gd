extends Node2D

# A ring of slowly orbiting blue soul-particles around the Commune
# extraction zone, purely decorative.

var particles: Array = []
const PARTICLE_COUNT := 16
@export var radius: float = 85.0

func _ready() -> void:
	for i in range(PARTICLE_COUNT):
		particles.append({
			"ang": randf_range(0.0, TAU), "speed": randf_range(0.3, 0.7),
			"r": randf_range(1.5, 3.2), "bob_phase": randf_range(0.0, TAU),
			"radius_var": randf_range(0.85, 1.15),
		})

func _process(delta: float) -> void:
	for p in particles:
		p["ang"] += p["speed"] * delta
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for p in particles:
		var r: float = radius * p["radius_var"]
		var pos := Vector2(cos(p["ang"]), sin(p["ang"])) * r
		var bob: float = sin(t * 2.0 + p["bob_phase"]) * 6.0
		pos.y += bob
		var flicker: float = 0.5 + 0.5 * sin(t * 2.5 + p["bob_phase"])
		draw_circle(pos, p["r"] * (0.7 + flicker * 0.5), Color(0.4, 0.75, 1.0, 0.35 + flicker * 0.4))
