extends CharacterBody2D

# The Gauntlet's side-scroller player controller - real gravity,
# jumping, and a melee swing instead of gunplay. Now using real
# character sprites (idle/run/punch/death) instead of polygon shapes.

const GRAVITY := 1300.0
const BASE_MOVE_SPEED := 260.0
const JUMP_VELOCITY := -720.0
const BASE_ATTACK_DAMAGE := 22
const ATTACK_RANGE := 55.0
const ATTACK_COOLDOWN := 0.35
const BASE_SHOOT_DAMAGE := 14
const SHOOT_COOLDOWN := 0.4

var move_speed: float = BASE_MOVE_SPEED
var attack_damage: int = BASE_ATTACK_DAMAGE
var shoot_damage: int = BASE_SHOOT_DAMAGE
var shoot_cooldown: float = SHOOT_COOLDOWN
var base_max_health: int = 100
var has_ranged_weapon: bool = false
var is_melee_equipped: bool = true
var is_swinging: bool = false
var _was_grounded: bool = true

var health: int = 100
var max_health: int = 100
var can_attack: bool = true
var can_shoot: bool = true
var facing: int = 1
var invuln_until_ms: int = 0
var bodies_in_range: Array = []
var is_dead: bool = false

signal died
signal health_changed(current: int, maximum: int)

@onready var sprite: Node = $AnimatedSprite
@onready var sword_pivot: Node2D = $SwordPivot
@onready var gun_pivot: Node2D = $GunPivot
@onready var gun_body: Polygon2D = $GunPivot/GunBody
@onready var gun_grip: Polygon2D = $GunPivot/GunGrip
@onready var muzzle: Marker2D = $GunPivot/Muzzle
@onready var attack_zone: Area2D = $AttackZone
@onready var attack_shape: CollisionShape2D = $AttackZone/CollisionShape2D
@onready var hp_bar: ProgressBar = $HpBar

# Dynamic weapon visuals - the gun's shape/color and the projectile it
# fires both change based on the equipped weapon's icon_key, so a
# railgun actually looks and shoots differently than a pistol instead
# of every gun being the same generic sidearm sprite.
const WEAPON_VISUALS := {
	"pistol": {"body_color": Color(0.16, 0.16, 0.18, 1), "grip_color": Color(0.1, 0.1, 0.11, 1), "scale": Vector2(0.85, 0.85), "proj_color": Color(0.35, 0.85, 1.0, 1), "proj_glow": Color(0.6, 0.95, 1.0, 0.5)},
	"rifle": {"body_color": Color(0.22, 0.24, 0.2, 1), "grip_color": Color(0.12, 0.13, 0.1, 1), "scale": Vector2(1.25, 1.0), "proj_color": Color(0.95, 0.85, 0.2, 1), "proj_glow": Color(1.0, 0.9, 0.4, 0.5)},
	"sniper": {"body_color": Color(0.15, 0.18, 0.24, 1), "grip_color": Color(0.08, 0.09, 0.12, 1), "scale": Vector2(1.6, 0.9), "proj_color": Color(0.6, 0.95, 1.0, 1), "proj_glow": Color(0.8, 1.0, 1.0, 0.5)},
	"railgun": {"body_color": Color(0.1, 0.28, 0.5, 1), "grip_color": Color(0.06, 0.16, 0.3, 1), "scale": Vector2(1.3, 1.15), "proj_color": Color(0.2, 0.6, 1.0, 1), "proj_glow": Color(0.4, 0.8, 1.0, 0.6)},
	"flamethrower": {"body_color": Color(0.4, 0.18, 0.05, 1), "grip_color": Color(0.22, 0.1, 0.03, 1), "scale": Vector2(1.2, 1.3), "proj_color": Color(1.0, 0.45, 0.1, 1), "proj_glow": Color(1.0, 0.65, 0.2, 0.55)},
	"thorn": {"body_color": Color(0.35, 0.05, 0.18, 1), "grip_color": Color(0.2, 0.03, 0.1, 1), "scale": Vector2(1.1, 1.1), "proj_color": Color(0.75, 0.1, 0.3, 1), "proj_glow": Color(0.9, 0.2, 0.4, 0.5)},
	"sword": {"body_color": Color(0.55, 0.08, 0.1, 1), "grip_color": Color(0.3, 0.05, 0.06, 1), "scale": Vector2(1.0, 1.0), "proj_color": Color(0.85, 0.15, 0.25, 1), "proj_glow": Color(1.0, 0.3, 0.35, 0.5)},
}
var weapon_proj_color: Color = Color(0.35, 0.85, 1.0, 1)
var weapon_proj_glow: Color = Color(0.6, 0.95, 1.0, 0.5)
var weapon_visual_scale: Vector2 = Vector2(0.85, 0.85)

const PET_SCENE := preload("res://scenes/Pet.tscn")
const PLAYER_PROJECTILE_SCENE := preload("res://scenes/GauntletPlayerProjectile.tscn")

const TEX_IDLE := preload("res://assets/sprites/gauntlet_player/idle.png")
const TEX_RUN := preload("res://assets/sprites/gauntlet_player/run.png")
const TEX_PUNCH := preload("res://assets/sprites/gauntlet_player/punch.png")
const TEX_DEATH := preload("res://assets/sprites/gauntlet_player/death.png")

func _ready() -> void:
	add_to_group("gauntlet_player")
	base_max_health = 100 + int((GameManager.gauntlet_best_level) * 0.0)
	_recompute_gauntlet_stats()
	health = max_health
	GameManager.gauntlet_equipment_changed.connect(_recompute_gauntlet_stats)
	attack_zone.monitoring = true
	attack_zone.body_entered.connect(_on_zone_entered)
	attack_zone.body_exited.connect(_on_zone_exited)

	# One-time setup only - this used to live inside _apply_gear_tint(),
	# which re-runs on every single equip/unequip via
	# gauntlet_equipment_changed. That meant every gear swap mid-run
	# spawned ANOTHER pet on top of the existing one and added another
	# duplicate health_changed listener.
	_spawn_pet()
	sprite.add_animation("idle", TEX_IDLE, 6)
	sprite.add_animation("run", TEX_RUN, 6)
	sprite.add_animation("punch", TEX_PUNCH, 4)
	sprite.add_animation("death", TEX_DEATH, 6)
	sprite.frame_rate = 10.0
	sprite.play("idle")

	hp_bar.max_value = max_health
	hp_bar.value = health
	health_changed.connect(func(cur, mx): hp_bar.max_value = mx; hp_bar.value = cur)

# Equipment actually matters mid-run now: stat bonuses apply for real,
# and the sprite gets a visible tint/glow matching the best-equipped
# rarity, so gearing up in the Gauntlet doll has a real payoff.
func _recompute_gauntlet_stats() -> void:
	var prev_max: int = max_health
	max_health = base_max_health + int(GameManager.get_gauntlet_equipped_bonus("max_health"))
	if prev_max > 0 and max_health != prev_max:
		health += (max_health - prev_max)
		health = clamp(health, 1, max_health)
	move_speed = BASE_MOVE_SPEED + GameManager.get_gauntlet_equipped_bonus("speed")
	attack_damage = BASE_ATTACK_DAMAGE + int(GameManager.get_gauntlet_equipped_bonus("damage"))
	shoot_damage = BASE_SHOOT_DAMAGE + int(GameManager.get_gauntlet_equipped_bonus("damage"))
	# fire_rate gear (e.g. "Squad Headset", "Tactical Comms Array") rolls
	# and displays fine (GauntletInventoryPanel.gd shows a real "+X% Fire
	# Rate" line) but was never actually applied anywhere - _shoot()'s
	# cooldown was a fixed constant, unlike Player.gd's non-Gauntlet
	# equivalent, which genuinely reduces shoot_cooldown via
	# get_equipped_bonus("fire_rate"). Same reduction shape here.
	shoot_cooldown = max(0.08, SHOOT_COOLDOWN - GameManager.get_gauntlet_equipped_bonus("fire_rate"))
	health_changed.emit(health, max_health)
	# Left-click is the only attack button now: it swings if you have
	# no weapon or a melee-type weapon (sword, thorn) equipped, or
	# shoots if you have a ranged-type weapon equipped. No more
	# separate right-click shoot.
	var equipped_weapon = GameManager.gauntlet_equipped_items.get("weapon")
	is_melee_equipped = equipped_weapon == null or GameManager.is_gauntlet_item_melee(equipped_weapon)
	has_ranged_weapon = equipped_weapon != null and not is_melee_equipped
	sword_pivot.visible = is_melee_equipped
	gun_pivot.visible = has_ranged_weapon
	_update_weapon_visual()
	_apply_gear_tint()

func _update_weapon_visual() -> void:
	var weapon = GameManager.gauntlet_equipped_items.get("weapon")
	var icon_key: String = weapon.get("icon_key", "pistol") if weapon != null else "pistol"
	var visuals: Dictionary = WEAPON_VISUALS.get(icon_key, WEAPON_VISUALS["pistol"])
	gun_body.color = visuals["body_color"]
	gun_grip.color = visuals["grip_color"]
	weapon_visual_scale = visuals["scale"]
	gun_pivot.scale = weapon_visual_scale
	weapon_proj_color = visuals["proj_color"]
	weapon_proj_glow = visuals["proj_glow"]

func _apply_gear_tint() -> void:
	var rarity: String = GameManager.get_gauntlet_best_equipped_rarity()
	var tint_colors := {
		"common": Color(1, 1, 1, 1), "uncommon": Color(0.85, 1.0, 0.85, 1),
		"rare": Color(0.8, 0.9, 1.1, 1), "epic": Color(0.95, 0.8, 1.15, 1),
		"legendary": Color(1.15, 0.95, 0.6, 1), "mythic": Color(1.2, 0.75, 0.9, 1),
		"exotic": Color(1.25, 0.7, 1.25, 1), "multiversal": Color(1.3, 1.2, 0.7, 1),
	}
	sprite.modulate = tint_colors.get(rarity, Color(1, 1, 1, 1))

func _spawn_pet() -> void:
	if GameManager.equipped_pet == "":
		return
	var pet = PET_SCENE.instantiate()
	pet.pet_id = GameManager.equipped_pet
	get_parent().call_deferred("add_child", pet)
	pet.set_deferred("global_position", global_position + Vector2(-40, 0))

func _on_zone_entered(body_hit: Node) -> void:
	if body_hit.is_in_group("gauntlet_enemy") and not bodies_in_range.has(body_hit):
		bodies_in_range.append(body_hit)

func _on_zone_exited(body_hit: Node) -> void:
	bodies_in_range.erase(body_hit)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	velocity.y += GRAVITY * delta

	var dir := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir += 1.0
	var stick_x := Input.get_joy_axis(GameManager.GAMEPAD_DEVICE, JOY_AXIS_LEFT_X)
	if absf(stick_x) > GameManager.STICK_DEADZONE:
		dir = clampf(dir + stick_x, -1.0, 1.0)
	velocity.x = dir * move_speed

	var jump_pressed := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE) or GameManager.is_action_pressed("jump")
	if jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY
		Sfx.play_jump()

	move_and_slide()

	var grounded := is_on_floor()
	if grounded and not _was_grounded:
		Sfx.play_land()
	_was_grounded = grounded

	# The character (and whatever's in their hands) faces the cursor
	# now, not the movement direction - a raw left/right sign is all
	# the sprite needs since it's a flip, not a full rotation.
	var to_mouse: Vector2 = _get_aim_point() - global_position
	if abs(to_mouse.x) > 1.0:
		facing = sign(to_mouse.x)
	sprite.flip_h = facing < 0
	# Attack zone always sits toward the cursor at a fixed reach, so
	# melee hits land wherever you're actually aiming.
	attack_zone.position = to_mouse.normalized() * 30.0 if to_mouse.length() > 1.0 else Vector2(30.0 * facing, -5.0)

	# The equipped gun follows the cursor - held at a fixed anchor near
	# the body, but freely rotating to point wherever the mouse is, the
	# same way weapons aim in the main game.
	if has_ranged_weapon:
		gun_pivot.look_at(_get_aim_point())
	# The sword does the same when idle - only pauses tracking during
	# the swing animation itself, which briefly takes over its rotation.
	elif is_melee_equipped and not is_swinging:
		sword_pivot.look_at(_get_aim_point())

	# Left-click (or the shoot trigger) is the only attack input: it
	# swings if a melee weapon (or nothing) is equipped, or shoots if a
	# ranged weapon is equipped - never both, and never via right-click.
	if GameManager.is_shoot_pressed():
		if is_melee_equipped:
			if can_attack:
				_attack()
		else:
			if can_shoot:
				_shoot()
	elif dir != 0.0:
		sprite.play("run")
	else:
		sprite.play("idle")

# Mirrors Player.gd's _get_aim_point() - the right stick gives a
# direction, not a position, so this turns it into a synthetic point far
# enough out that every existing get_global_mouse_position()-based aim
# call here works unmodified, falling back to the real mouse the instant
# the stick is released.
const GAMEPAD_AIM_POINT_DISTANCE := 1000.0

# Cached per physics frame - same fix as Player.gd's own _get_aim_point(),
# see its comment for why. Called up to 3x per tick here (facing/attack
# zone, then gun_pivot or sword_pivot look_at).
var _cached_aim_point: Vector2 = Vector2.ZERO
var _cached_aim_point_physics_frame: int = -1

func _get_aim_point() -> Vector2:
	var current_frame := Engine.get_physics_frames()
	if current_frame == _cached_aim_point_physics_frame:
		return _cached_aim_point
	var stick_dir: Vector2 = GameManager.get_gamepad_aim_direction()
	var point: Vector2 = (global_position + stick_dir * GAMEPAD_AIM_POINT_DISTANCE) if stick_dir != Vector2.ZERO else get_global_mouse_position()
	_cached_aim_point = point
	_cached_aim_point_physics_frame = current_frame
	return point

func _shoot() -> void:
	can_shoot = false
	Sfx.play_energy_shot()
	var aim_dir: Vector2 = _get_aim_point() - muzzle.global_position
	if aim_dir.length() < 1.0:
		aim_dir = Vector2(facing, 0)
	aim_dir = aim_dir.normalized()
	var proj = PLAYER_PROJECTILE_SCENE.instantiate()
	proj.bolt_color = weapon_proj_color
	proj.glow_color = weapon_proj_glow
	get_parent().add_child(proj)
	proj.global_position = muzzle.global_position
	proj.direction = aim_dir
	proj.rotation = aim_dir.angle()
	if "damage" in proj:
		proj.damage = shoot_damage
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

func _attack() -> void:
	can_attack = false
	is_swinging = true
	Sfx.play_sword_swing()
	sprite.play("punch", true)
	_swing_sword()
	for body_hit in bodies_in_range.duplicate():
		if is_instance_valid(body_hit) and body_hit.has_method("take_damage"):
			body_hit.take_damage(attack_damage)
	bodies_in_range = bodies_in_range.filter(func(b): return is_instance_valid(b))
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_attack = true

const SWORD_WINDUP_OFFSET := -1.0
const SWORD_SLASH_OFFSET := 0.9

func _swing_sword() -> void:
	# The whole arc is built around wherever the cursor is aimed at the
	# moment of the swing, not a fixed left/right slash - so attacking
	# up-and-to-the-right looks and hits differently than attacking
	# straight down at your feet.
	var aim_angle: float = (_get_aim_point() - sword_pivot.global_position).angle()
	var swing_tw := create_tween()
	swing_tw.tween_property(sword_pivot, "rotation", aim_angle + SWORD_WINDUP_OFFSET, 0.05)
	swing_tw.tween_property(sword_pivot, "rotation", aim_angle + SWORD_SLASH_OFFSET, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing_tw.tween_property(sword_pivot, "rotation", aim_angle, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	swing_tw.tween_callback(func(): is_swinging = false)

func take_damage(amount: int) -> void:
	if is_dead or Time.get_ticks_msec() < invuln_until_ms:
		return
	invuln_until_ms = Time.get_ticks_msec() + 400
	health -= amount
	health_changed.emit(health, max_health)
	if health <= 0:
		health = 0
		is_dead = true
		sprite.play("death")
		died.emit()
