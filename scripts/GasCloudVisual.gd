extends Node2D

var particles: Array = []
const COUNT := 18
const RADIUS := 40.0

func _ready() -> void:
	for i in range(COUNT):
		particles.append({
			"ang": randf_range(0.0, TAU), "dist": randf_range(0.2, 1.0),
			"speed": randf_range(0.15, 0.4), "r": randf_range(6.0, 14.0),
			"phase": randf_range(0.0, TAU),
		})

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for p in particles:
		var ang: float = p["ang"] + t * p["speed"]
		var d: float = RADIUS * p["dist"]
		var pos := Vector2(cos(ang), sin(ang)) * d
		var pulse: float = 0.5 + 0.5 * sin(t * 1.5 + p["phase"])
		draw_circle(pos, p["r"] * (0.7 + pulse * 0.3), Color(0.35, 0.85, 0.25, 0.22 + pulse * 0.12))
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color(0.3, 0.75, 0.2, 0.15))
