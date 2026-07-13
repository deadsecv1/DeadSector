extends Area2D

# One toxic gas cloud within the Radiation Zone. Unlike the old design
# (damage anywhere in a big hex), damage only happens while actually
# standing inside a cloud's puffy visual - so the danger is legible at a
# glance instead of an invisible blanket effect.

@export var cloud_radius: float = 160.0
@export var damage_per_tick: int = 12
@export var tick_interval: float = 1.0

var player_inside: bool = false
var player_ref: Node = null
var tick_timer: float = 0.0
var drift_offset: Vector2 = Vector2.ZERO
var base_position: Vector2
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
const WANDER_LEASH := 90.0

@onready var puff: Node2D = $Puff
@onready var collider: CollisionShape2D = $CollisionShape2D
@onready var particles: CPUParticles2D = $Particles

func _ready() -> void:
	base_position = position
	if collider.shape is CircleShape2D:
		collider.shape = collider.shape.duplicate()
		collider.shape.radius = cloud_radius
	var scale_f: float = cloud_radius / 90.0
	puff.scale = Vector2(scale_f, scale_f)
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)
	randomize()
	drift_offset = Vector2(randf_range(0.0, TAU), randf_range(0.0, TAU))
	_wander_target = Vector2.ZERO
	_wander_timer = randf_range(2.0, 4.0)
	_setup_particles(scale_f)

func _setup_particles(scale_f: float) -> void:
	particles.emitting = true
	particles.amount = int(26 * scale_f)
	particles.lifetime = 2.2
	particles.preprocess = 2.2
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 6.0
	particles.initial_velocity_max = 22.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5
	particles.color = Color(0.55, 0.95, 0.2, 0.5)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = cloud_radius * 0.7

func _on_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = true
		player_ref = body

func _on_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = false

func _process(_delta: float) -> void:
	# Visual-only updates belong here - actually moving the Area2D
	# itself (below, in _physics_process) is what has to stay on the
	# physics tick, or collision detection against the player desyncs
	# and body_entered/body_exited stop firing reliably.
	var t := Time.get_ticks_msec() * 0.0004
	puff.modulate.a = 0.7 + 0.15 * sin(t * 2.0)

func _physics_process(delta: float) -> void:
	# Slow wandering on top of the small drift wobble - picks a new
	# nearby point every few seconds and eases toward it, so the cloud
	# genuinely moves around within the Radiation Zone instead of just
	# jittering in place. Area2D transforms need to be set here (the
	# physics tick), not in _process, for collision detection to be
	# reliable - this was also the actual cause of the clouds not
	# dealing damage at all.
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(3.0, 5.5)
		_wander_target = Vector2(randf_range(-WANDER_LEASH, WANDER_LEASH), randf_range(-WANDER_LEASH, WANDER_LEASH))
	var t := Time.get_ticks_msec() * 0.0004
	var wobble := Vector2(sin(t + drift_offset.x) * 14.0, cos(t * 0.8 + drift_offset.y) * 10.0)
	var target_pos: Vector2 = base_position + _wander_target + wobble
	position = position.lerp(target_pos, clamp(delta * 0.6, 0.0, 1.0))

	if not player_inside:
		return
	if GameManager.has_gas_mask():
		return
	if player_ref == null or not is_instance_valid(player_ref) or not player_ref.alive:
		return
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		player_ref.take_damage(damage_per_tick)
