extends Area2D

# The actual blinding cloud left behind after a Spore Cloud plant is
# shot and bursts. Anyone who walks into it gets their flashlight
# scrambled for as long as they're inside (and briefly after).

const DURATION := 5.0
const RADIUS := 65.0

var _life: float = 0.0
var particles: Array = []
var _blinded_bodies: Array = []

@onready var shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	body_entered.connect(_on_entered)
	for i in range(16):
		particles.append({
			"ang": randf_range(0.0, TAU), "dist": randf_range(0.15, 1.0),
			"speed": randf_range(0.1, 0.3), "r": randf_range(4.0, 10.0),
			"phase": randf_range(0.0, TAU),
		})
	set_process(true)

func _on_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("disable_flashlight") and not _blinded_bodies.has(body):
		_blinded_bodies.append(body)
		body.disable_flashlight(2.5)

func _process(delta: float) -> void:
	_life += delta
	var fade: float = 1.0
	if _life > DURATION - 1.0:
		fade = clamp(DURATION - _life, 0.0, 1.0)
	modulate.a = fade
	if _life >= DURATION:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	draw_circle(Vector2.ZERO, RADIUS, Color(0.55, 0.85, 0.3, 0.18))
	for p in particles:
		var ang: float = p["ang"] + t * p["speed"]
		var d: float = RADIUS * p["dist"]
		var pos := Vector2(cos(ang), sin(ang)) * d
		var pulse: float = 0.5 + 0.5 * sin(t * 1.5 + p["phase"])
		draw_circle(pos, p["r"] * (0.6 + pulse * 0.4), Color(0.6, 0.9, 0.35, 0.2 * pulse))
