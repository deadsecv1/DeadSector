extends "res://scripts/Enemy.gd"

# Noxious Bat - a visually distinct flying enemy: purple, winged, hovers
# with a bob instead of walking on legs, and fires purple toxic bolts
# instead of the regular enemy pistol shot.
#
# Used to just recolor the shared humanoid rig (same octagon torso/head
# every Raider uses) and glue two small triangles on - still had a
# skin-toned human head, a human hand gripping a pistol, and (35% of the
# time, from Enemy.gd's base _apply_random_raider_look() roll) even a
# human baseball cap, so it read as "a person, but purple" rather than a
# bat. Hides every human-specific part instead and builds much larger,
# actually wing-shaped membranes.

@onready var head: Polygon2D = $Visuals/Head
@onready var head_outline: Line2D = $Visuals/HeadOutline

var wing_phase: float = 0.0
var left_wing: Polygon2D
var right_wing: Polygon2D

func _ready() -> void:
	super._ready()
	add_to_group("bat")
	torso.color = Color(0.42, 0.12, 0.55, 1)
	# A strap/harness accessory and a gun-gripping hand don't make sense on
	# a creature - hidden rather than recolored like the body is.
	chest_strap.visible = false
	mask.visible = false
	cap.visible = false
	left_leg.visible = false
	right_leg.visible = false
	gun_visual.visible = false
	# Same dark purple as the body rather than the default skin tone, so
	# there's no human face hiding in the middle of the silhouette -
	# muzzle.global_position (still a child of the now-hidden GunVisual)
	# keeps working fine for _shoot() below regardless of visibility.
	head.color = Color(0.28, 0.06, 0.35, 1)
	head_outline.default_color = Color(0.03, 0.03, 0.04, 1)
	wing_phase = randf() * TAU
	_build_wings()

func _build_wings() -> void:
	left_wing = Polygon2D.new()
	left_wing.polygon = PackedVector2Array([
		Vector2(-2, -4), Vector2(-16, -14), Vector2(-30, -10), Vector2(-26, 0),
		Vector2(-32, 4), Vector2(-20, 8), Vector2(-8, 10), Vector2(-2, 6),
	])
	left_wing.color = Color(0.5, 0.15, 0.62, 0.88)
	left_wing.position = Vector2(-4, -2)
	visuals.add_child(left_wing)
	visuals.move_child(left_wing, torso.get_index())

	right_wing = Polygon2D.new()
	right_wing.polygon = PackedVector2Array([
		Vector2(2, -4), Vector2(16, -14), Vector2(30, -10), Vector2(26, 0),
		Vector2(32, 4), Vector2(20, 8), Vector2(8, 10), Vector2(2, 6),
	])
	right_wing.color = Color(0.5, 0.15, 0.62, 0.88)
	right_wing.position = Vector2(4, -2)
	visuals.add_child(right_wing)
	visuals.move_child(right_wing, torso.get_index())

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	wing_phase += delta * 9.0
	# A constant hover lift plus a gentle bob, layered on top of whatever
	# _animate() already set this frame.
	visuals.position.y += -4.0 + sin(wing_phase) * 2.0
	var flap: float = sin(wing_phase)
	left_wing.rotation = -0.3 + flap * 0.35
	right_wing.rotation = 0.3 - flap * 0.35

func _shoot() -> void:
	can_shoot = false
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = (player.global_position - muzzle.global_position).normalized()
	bullet.is_enemy_bullet = true
	# attack_damage (12 baseline, set on the scene node) already gets scaled
	# with player progression by Enemy.gd's _ready() the same as every other
	# regular enemy - this used to hardcode a flat 12 that ignored that
	# entirely, so the bat stopped mattering at all once a player leveled up.
	bullet.damage = attack_damage
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.modulate = Color(0.65, 0.2, 0.85, 1)
	bullet.scale = Vector2(1.25, 1.25)
	recoil = -5.0
	_flash_muzzle()
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true
