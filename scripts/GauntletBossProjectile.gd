extends Area2D

# The Bloodline boss's ranged bolt - slower and bigger than a regular
# enemy shot (and visually distinct: dark violet instead of warm red)
# so it reads clearly as "dodge this" rather than blending into the
# regular ranged-enemy bolts.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 210.0
var damage: int = 16
var lifetime: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_hit)

func _process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_hit(body: Node) -> void:
	if body.is_in_group("gauntlet_player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_impact_burst()
		queue_free()

func _impact_burst() -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 14
	particles.lifetime = 0.35
	particles.explosiveness = 1.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.75, 0.2, 0.95, 1)
	get_parent().call_deferred("add_child", particles)
	particles.call_deferred("set", "global_position", global_position)
	particles.call_deferred("set", "emitting", true)
	get_tree().create_timer(particles.lifetime + 0.15).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)
