extends Area2D

# A permanent glowing violet hazard patch, unlike GasCloud which is
# temporary - Void Trench's irradiated puddles just sit there forever,
# slowing and ticking damage on anything that wanders in.

@export var puddle_radius: float = 50.0
const TICK_INTERVAL := 0.6
const TICK_DAMAGE := 4

var _bodies_inside: Array = []
var _tick_timer: float = 0.0
var particles: Array = []

@onready var shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = puddle_radius
	shape.shape = circle
	body_entered.connect(func(b):
		if not _bodies_inside.has(b):
			_bodies_inside.append(b)
		if b.has_method("set_slowed"):
			b.set_slowed(true)
	)
	body_exited.connect(func(b):
		_bodies_inside.erase(b)
		if is_instance_valid(b) and b.has_method("set_slowed"):
			b.set_slowed(false)
	)
	for i in range(14):
		particles.append({
			"ang": randf_range(0.0, TAU), "dist": randf_range(0.2, 0.95),
			"r": randf_range(3.0, 7.0), "phase": randf_range(0.0, TAU),
		})
	set_process(true)

func _process(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = TICK_INTERVAL
		for b in _bodies_inside.duplicate():
			if not is_instance_valid(b):
				_bodies_inside.erase(b)
				continue
			if b.has_method("take_damage"):
				b.take_damage(TICK_DAMAGE)
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	draw_circle(Vector2.ZERO, puddle_radius, Color(0.35, 0.1, 0.5, 0.35))
	draw_circle(Vector2.ZERO, puddle_radius * 0.7, Color(0.55, 0.2, 0.75, 0.3))
	for p in particles:
		var ang: float = p["ang"] + t * 0.2
		var d: float = puddle_radius * p["dist"]
		var pos := Vector2(cos(ang), sin(ang)) * d
		var glow: float = 0.5 + 0.5 * sin(t * 1.8 + p["phase"])
		draw_circle(pos, p["r"] * (0.6 + glow * 0.4), Color(0.8, 0.4, 1.0, 0.25 * glow))
