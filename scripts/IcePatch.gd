extends Area2D

# A patch of ice left along the path of an ice-elemental shot. Fades
# back to normal ground after a few seconds. Anything standing on it
# gets tagged "on_ice" (read by Player.gd/Enemy.gd movement code) for a
# real sliding feel - reduced control, velocity carries further.

const DURATION := 3.0
const RADIUS := 22.0

var _life: float = 0.0

@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	set_process(true)

func _process(delta: float) -> void:
	_life += delta
	if _life > DURATION - 0.8:
		visual.modulate.a = clamp((DURATION - _life) / 0.8, 0.0, 1.0)
	if _life >= DURATION:
		queue_free()

func _on_entered(body: Node) -> void:
	if body.has_method("set_on_ice"):
		body.set_on_ice(true)

func _on_exited(body: Node) -> void:
	if is_instance_valid(body) and body.has_method("set_on_ice"):
		body.set_on_ice(false)
