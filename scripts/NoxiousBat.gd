extends "res://scripts/Enemy.gd"

# Noxious Bat - a visually distinct flying enemy: purple, winged, hovers
# with a bob instead of walking on legs, and fires purple toxic bolts
# instead of the regular enemy pistol shot.

var wing_phase: float = 0.0
var left_wing: Polygon2D
var right_wing: Polygon2D

func _ready() -> void:
	super._ready()
	add_to_group("bat")
	torso.color = Color(0.42, 0.12, 0.55, 1)
	chest_strap.color = Color(0.22, 0.05, 0.3, 1)
	mask.visible = false
	left_leg.visible = false
	right_leg.visible = false
	wing_phase = randf() * TAU
	_build_wings()

func _build_wings() -> void:
	left_wing = Polygon2D.new()
	left_wing.polygon = PackedVector2Array([Vector2(0, 0), Vector2(-15, -6), Vector2(-17, 5), Vector2(-6, 7)])
	left_wing.color = Color(0.5, 0.15, 0.62, 0.88)
	left_wing.position = Vector2(-6, -2)
	visuals.add_child(left_wing)

	right_wing = Polygon2D.new()
	right_wing.polygon = PackedVector2Array([Vector2(0, 0), Vector2(15, -6), Vector2(17, 5), Vector2(6, 7)])
	right_wing.color = Color(0.5, 0.15, 0.62, 0.88)
	right_wing.position = Vector2(6, -2)
	visuals.add_child(right_wing)

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
	bullet.damage = 12
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	bullet.modulate = Color(0.65, 0.2, 0.85, 1)
	bullet.scale = Vector2(1.25, 1.25)
	recoil = -5.0
	_flash_muzzle()
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true
