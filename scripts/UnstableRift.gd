extends Area2D

# A crack in reality - deals real periodic damage to anyone standing
# too close, but can be "collapsed" by unloading enough damage into it
# (shoot it), which guarantees a burst of high-tier loot before it
# seals itself back up.

const TICK_INTERVAL := 0.7
const TICK_DAMAGE := 9
const RADIUS := 44.0
var health: int = 40
var collapsed: bool = false

var _bodies_inside: Array = []
var _tick_timer: float = 0.0

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Node2D = $Visual

func _ready() -> void:
	add_to_group("shootable_hazard")
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	body_entered.connect(func(b):
		if not _bodies_inside.has(b):
			_bodies_inside.append(b)
	)
	body_exited.connect(func(b): _bodies_inside.erase(b))
	set_process(true)

func take_damage(amount: int) -> void:
	if collapsed:
		return
	health -= amount
	if health <= 0:
		_collapse()

func _collapse() -> void:
	collapsed = true
	GameManager.toast_requested.emit("The rift collapses, spilling something valuable...")
	var rolled: Array = GameManager.roll_wandering_trader_stock(1)
	if not rolled.is_empty():
		GameManager.add_to_vicinity(rolled[0].duplicate(true), global_position)
	queue_free()

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
	visual.queue_redraw()
