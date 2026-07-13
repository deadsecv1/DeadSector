extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 340.0
var damage: int = 10
var lifetime: float = 2.5

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
	particles.amount = 10
	particles.lifetime = 0.3
	particles.explosiveness = 1.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 130.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.2
	particles.color = Color(0.95, 0.35, 0.2, 1)
	var parent := get_parent()
	if parent == null:
		return
	parent.call_deferred("add_child", particles)
	particles.call_deferred("set", "global_position", global_position)
	particles.call_deferred("set", "emitting", true)
