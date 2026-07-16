extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT
var is_enemy_bullet: bool = false
var is_operator_bullet: bool = false
var is_crit: bool = false
var style: String = "pistol"
var is_poison: bool = false
var poison_damage: int = 3
var poison_duration: float = 3.0
var is_electric: bool = false
var is_frost: bool = false
var is_burning: bool = false
var source_name: String = ""
var source_weapon: String = ""

@onready var pistol_visual: Node2D = $PistolVisual
@onready var rifle_visual: Node2D = $RifleVisual

func _ready() -> void:
	rotation = direction.angle()

	if not is_enemy_bullet and style == "rifle":
		pistol_visual.visible = false
		rifle_visual.visible = true
		speed = 800.0
	else:
		pistol_visual.visible = true
		rifle_visual.visible = false

	if not is_enemy_bullet and style == "flamethrower":
		speed = 420.0
		lifetime = 0.35
		scale = Vector2(1.8, 1.8)
		modulate = Color(1.0, 0.5, 0.15, 0.9)
	elif not is_enemy_bullet and style == "thorn":
		modulate = Color(0.4, 0.85, 0.25, 1)
	elif not is_enemy_bullet and style == "railgun":
		speed = 1300.0
		scale = Vector2(2.2, 1.3)
		modulate = Color(1.0, 0.95, 0.35, 1)
	elif not is_enemy_bullet and style == "sniper":
		speed = 1500.0
		scale = Vector2(1.6, 1.0)
		modulate = Color(0.55, 0.85, 1.0, 1)
	elif not is_enemy_bullet and style == "shotgun":
		scale = Vector2(0.65, 0.65)
		modulate = Color(1.0, 0.8, 0.4, 1)
	elif not is_enemy_bullet and style == "pistol":
		modulate = Color(1.0, 0.95, 0.75, 1)
	elif not is_enemy_bullet and style == "alpha_cannon":
		speed = 1000.0
		scale = Vector2(2.0, 1.4)
		modulate = Color(1.0, 0.85, 0.3, 1)
		_build_alpha_trail()
	elif not is_enemy_bullet and style == "tech_tester_sidearm":
		speed = 750.0
		scale = Vector2(1.3, 1.1)
		modulate = Color(0.5, 0.9, 1.0, 1)
		_build_tech_tester_trail()
	elif is_enemy_bullet and is_operator_bullet:
		# Operators shoot something visibly sharper than a regular
		# Raider's flat red-orange bolt - a hot electric-blue streak
		# with its own trailing sparkle, so you can tell at a glance
		# you're being shot at by a real threat.
		scale = Vector2(1.3, 1.3)
		modulate = Color(0.3, 0.85, 1.0, 1)
		_build_operator_trail()
	else:
		modulate = Color(1, 0.4, 0.3, 1) if is_enemy_bullet else Color(1, 1, 1, 1)
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(func(): queue_free())

# A continuous prismatic sparkle trail that follows the Alpha Cannon's
# projectile - the particles are emitted in world space (not local), so
# once released they stay put and the bullet flies away from them,
# reading as a trail rather than a blob that moves with the bullet.
func _build_alpha_trail() -> void:
	var trail := CPUParticles2D.new()
	add_child(trail)
	trail.local_coords = false
	trail.emitting = true
	trail.amount = 20
	trail.lifetime = 0.4
	trail.direction = Vector2.ZERO
	trail.spread = 180.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 4.0
	trail.initial_velocity_max = 18.0
	trail.scale_amount_min = 1.2
	trail.scale_amount_max = 2.6
	trail.color = Color(1.0, 0.9, 0.5, 0.85)

# A short electric-blue sparkle trail for Real Player operator shots -
# same world-space-emission trick as the Alpha Cannon trail above, just
# smaller and cooler-toned to fit a hostile-but-sharp read.
func _build_operator_trail() -> void:
	var trail := CPUParticles2D.new()
	add_child(trail)
	trail.local_coords = false
	trail.emitting = true
	trail.amount = 12
	trail.lifetime = 0.28
	trail.direction = Vector2.ZERO
	trail.spread = 180.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 3.0
	trail.initial_velocity_max = 12.0
	trail.scale_amount_min = 0.8
	trail.scale_amount_max = 1.8
	trail.color = Color(0.4, 0.85, 1.0, 0.8)

# A quick, cheap electric-blue streak for the Tech Tester's Sidearm -
# same world-space-emission trick as the trails above. Now that this
# weapon fires 3 projectiles per shot at its already-absurd fire rate
# (up to ~90 bullets/second), amount is trimmed even further than
# before to compensate - the "cool" factor comes from a brighter,
# two-layer glow (a hot near-white core plus a softer blue halo)
# instead of raw particle volume, so it still reads as an electric
# streak without piling up during a sustained burst.
func _build_tech_tester_trail() -> void:
	var glow := CPUParticles2D.new()
	add_child(glow)
	glow.local_coords = false
	glow.emitting = true
	glow.amount = 3
	glow.lifetime = 0.14
	glow.direction = Vector2.ZERO
	glow.spread = 180.0
	glow.gravity = Vector2.ZERO
	glow.initial_velocity_min = 2.0
	glow.initial_velocity_max = 6.0
	glow.scale_amount_min = 1.6
	glow.scale_amount_max = 2.4
	glow.color = Color(0.75, 0.95, 1.0, 0.5)

	var trail := CPUParticles2D.new()
	add_child(trail)
	trail.local_coords = false
	trail.emitting = true
	trail.amount = 4
	trail.lifetime = 0.16
	trail.direction = Vector2.ZERO
	trail.spread = 180.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 3.0
	trail.initial_velocity_max = 9.0
	trail.scale_amount_min = 0.7
	trail.scale_amount_max = 1.4
	trail.color = Color(0.55, 0.9, 1.0, 0.75)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if not is_enemy_bullet and is_frost:
		_ice_trail_timer -= delta
		if _ice_trail_timer <= 0.0:
			_ice_trail_timer = 0.035
			_spawn_ice_patch()

const BLOOD_SCENE := preload("res://scenes/BloodSplatter.tscn")
const BLOOD_DECAL_SCENE := preload("res://scenes/BloodDecal.tscn")
const GAS_CLOUD_SCENE := preload("res://scenes/GasCloud.tscn")
const ICE_PATCH_SCENE := preload("res://scenes/IcePatch.tscn")
const SCORCH_SCENE := preload("res://scenes/ScorchZone.tscn")
const LIGHTNING_ARC_SCENE := preload("res://scenes/LightningArc.tscn")
const CHAIN_RANGE := 130.0

var pierce_remaining: int = 0
var hit_bodies: Array = []
var _ice_trail_timer: float = 0.0

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("walls"):
		if is_poison:
			_spawn_gas_cloud()
		elif is_burning:
			_spawn_scorch()
		queue_free()
		return
	if is_enemy_bullet and body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, source_name, source_weapon, -direction)
		_spawn_blood()
		if body.has_node("Camera2D"):
			body.get_node("Camera2D").shake(6.0)
		queue_free()
	elif not is_enemy_bullet and body.is_in_group("enemy"):
		if hit_bodies.has(body):
			return
		hit_bodies.append(body)
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if is_poison and body.has_method("apply_poison"):
			body.apply_poison(poison_damage, poison_duration)
		_spawn_blood()
		_spawn_damage_number()
		if is_poison:
			_spawn_gas_cloud()
		if is_burning:
			_spawn_scorch()
			if body.has_method("apply_poison"):
				body.apply_poison(3, 3.0)
		if is_electric:
			_chain_lightning(body)
		if pierce_remaining > 0:
			pierce_remaining -= 1
		else:
			queue_free()
	elif not is_enemy_bullet and body.is_in_group("shootable_hazard"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()

func _chain_lightning(from_body: Node) -> void:
	# Railgun's real identity - the shot arcs to a second nearby enemy
	# and hits it too, on top of piercing through the first.
	var best: Node = null
	var best_dist := CHAIN_RANGE
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == from_body or hit_bodies.has(other) or not is_instance_valid(other):
			continue
		var d: float = from_body.global_position.distance_to(other.global_position)
		if d < best_dist:
			best_dist = d
			best = other
	if best == null:
		return
	hit_bodies.append(best)
	var chain_damage: int = int(damage * 0.6)
	if best.has_method("take_damage"):
		best.take_damage(chain_damage)
	var arc = LIGHTNING_ARC_SCENE.instantiate()
	get_tree().current_scene.add_child(arc)
	arc.setup(from_body.global_position, best.global_position)

func _spawn_gas_cloud() -> void:
	var cloud = GAS_CLOUD_SCENE.instantiate()
	get_tree().current_scene.add_child(cloud)
	cloud.global_position = global_position
	cloud.damage_per_tick = poison_damage

func _spawn_ice_patch() -> void:
	var patch = ICE_PATCH_SCENE.instantiate()
	get_tree().current_scene.add_child(patch)
	patch.global_position = global_position

func _spawn_scorch() -> void:
	var scorch = SCORCH_SCENE.instantiate()
	get_tree().current_scene.add_child(scorch)
	scorch.global_position = global_position

func _spawn_blood() -> void:
	var blood = BLOOD_SCENE.instantiate()
	get_tree().current_scene.add_child(blood)
	blood.global_position = global_position
	var decal = BLOOD_DECAL_SCENE.instantiate()
	get_tree().current_scene.add_child(decal)
	decal.global_position = global_position

func _spawn_damage_number() -> void:
	DamageNumber.get_instance(get_tree().current_scene, global_position + Vector2(0, -12), damage, is_crit)
