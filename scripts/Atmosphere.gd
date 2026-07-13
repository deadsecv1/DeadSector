extends Node2D

# Lightweight drifting dust/pollen particles across the map, for a bit of
# ambient life. Kept to a modest particle count since it redraws every
# frame across a large arena.

@export var area_size: Vector2 = Vector2(2700, 1840)

var motes: Array = []
const MOTE_COUNT := 55

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var half := area_size / 2.0
	for i in range(MOTE_COUNT):
		motes.append({
			"pos": Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y)),
			"dir": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3)).normalized(),
			"speed": rng.randf_range(6.0, 18.0),
			"radius": rng.randf_range(1.0, 2.4),
			"phase": rng.randf_range(0, TAU),
		})

func _process(delta: float) -> void:
	var half := area_size / 2.0
	for m in motes:
		m["pos"] += m["dir"] * m["speed"] * delta
		if m["pos"].x > half.x:
			m["pos"].x = -half.x
		elif m["pos"].x < -half.x:
			m["pos"].x = half.x
		if m["pos"].y > half.y:
			m["pos"].y = -half.y
		elif m["pos"].y < -half.y:
			m["pos"].y = half.y
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for m in motes:
		var twinkle: float = 0.4 + 0.4 * (0.5 + 0.5 * sin(t * 1.5 + m["phase"]))
		draw_circle(m["pos"], m["radius"], Color(0.9, 0.95, 0.8, twinkle * 0.35))
