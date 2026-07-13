extends Area2D

# A lingering toxic gas cloud, left behind by Toxinbrand-style (poison)
# weapons wherever the shot actually lands - not just a single poison
# tick on the enemy hit, but a real area anything can wander into.

const DURATION := 4.5
const TICK_INTERVAL := 0.5
const RADIUS := 46.0

var damage_per_tick: int = 3
var _life: float = 0.0
var _tick_timer: float = 0.0
var _bodies_inside: Array = []

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Node2D = $Visual

func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	body_entered.connect(func(b): if not _bodies_inside.has(b): _bodies_inside.append(b))
	body_exited.connect(func(b): _bodies_inside.erase(b))
	set_process(true)

func _process(delta: float) -> void:
	_life += delta
	_tick_timer -= delta
	var fade: float = 1.0
	if _life > DURATION - 1.0:
		fade = clamp((DURATION - _life), 0.0, 1.0)
	visual.modulate.a = fade
	if _life >= DURATION:
		queue_free()
		return
	if _tick_timer <= 0.0:
		_tick_timer = TICK_INTERVAL
		for b in _bodies_inside.duplicate():
			if not is_instance_valid(b):
				_bodies_inside.erase(b)
				continue
			if b.is_in_group("enemy") and b.has_method("take_damage"):
				b.take_damage(damage_per_tick)
			elif b.is_in_group("player") and b.has_method("take_damage"):
				b.take_damage(damage_per_tick)
	visual.queue_redraw()
