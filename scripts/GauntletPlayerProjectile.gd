extends Area2D

# The player's own ranged shot in the Gauntlet - damages enemies
# instead of the player. Color/glow are set dynamically per-shot to
# match whichever weapon is equipped (see GauntletPlayer.gd), so a
# railgun bolt looks different from a pistol bolt instead of every
# gun firing the same fixed blue shot.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 480.0
var damage: int = 14
var lifetime: float = 1.4
var bolt_color: Color = Color(0.35, 0.85, 1.0, 1)
var glow_color: Color = Color(0.6, 0.95, 1.0, 0.5)

@onready var bolt: Polygon2D = $Bolt
@onready var glow: Polygon2D = $Glow
@onready var trail: CPUParticles2D = $Trail

func _ready() -> void:
	body_entered.connect(_on_hit)
	bolt.color = bolt_color
	glow.color = glow_color
	trail.color = Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.8)

func _process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_hit(body: Node) -> void:
	if (body.is_in_group("gauntlet_enemy") or body.is_in_group("gauntlet_boss")) and body.has_method("take_damage"):
		body.take_damage(damage)
		_impact_burst()
		queue_free()

func _impact_burst() -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 12
	particles.lifetime = 0.3
	particles.explosiveness = 1.0
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 140.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5
	particles.color = bolt_color
	var parent := get_parent()
	if parent == null:
		return
	parent.call_deferred("add_child", particles)
	particles.call_deferred("set", "global_position", global_position)
	particles.call_deferred("set", "emitting", true)
