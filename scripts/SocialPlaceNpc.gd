extends CharacterBody2D

# A purely decorative "real player" for the Social Place hub - reuses
# Enemy.tscn's rich visuals via set_script() (same technique ArenaAlly.gd
# uses), but with idle wander instead of any combat AI, and deliberately
# never joins the "enemy" group - Bullet.gd only damages "enemy"-group
# bodies (see Bullet.gd's hit checks), so the player can fire here
# freely without anyone, including these NPCs, ever taking damage. Also
# never joins "player", so its own cosmetic gunfire below can't hit
# the real player either.

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const BulletScene := preload("res://scenes/Bullet.tscn")
const WEAPON_ICON_KEYS := ["pistol", "rifle", "shotgun", "sniper"]
const CHAT_LINES := [
	"Hey there.", "Nice loadout.", "First time in the Sector?", "Rough raid out there today.",
	"You seen the new gear at Traders?", "Good luck out there.", "Watch your six.",
]

const ROAM_RADIUS := 160.0
const BASE_SPEED := 70.0
const LOOK_AROUND_INTERVAL_MIN := 1.5
const LOOK_AROUND_INTERVAL_MAX := 3.5
const SHOOT_CHANCE_PER_CHECK := 0.12
const SHOOT_CHECK_INTERVAL := 4.0
const CHAT_RANGE := 140.0
const CHAT_COOLDOWN_SECONDS := 6.0

var origin: Vector2 = Vector2.ZERO
var roam_target: Vector2 = Vector2.ZERO
var roam_timer: float = 0.0
var look_timer: float = 0.0
var look_angle: float = 0.0
var shoot_check_timer: float = 0.0
var chat_cooldown_until_ms: int = 0

@onready var visuals: Node2D = $Visuals
@onready var left_leg: Polygon2D = $Visuals/LeftLeg
@onready var right_leg: Polygon2D = $Visuals/RightLeg
@onready var torso: Polygon2D = $Visuals/Torso
@onready var chest_strap: Polygon2D = $Visuals/ChestStrap
@onready var mask: Polygon2D = $Visuals/Mask
@onready var cap: Polygon2D = $Visuals/Cap
@onready var name_tag: Label = $Visuals/NameTag
@onready var external_sprite: Sprite2D = $Visuals/ExternalSprite
@onready var gun_pivot: Node2D = $Visuals/GunPivot
@onready var muzzle: Marker2D = $Visuals/GunPivot/GunVisual/Muzzle
@onready var muzzle_flash: Polygon2D = $Visuals/GunPivot/GunVisual/MuzzleFlash

var walk_cycle: float = 0.0

func _ready() -> void:
	add_to_group("social_place_npc")
	origin = global_position
	# Same tactical-green look Enemy.gd's real-player variant uses, with
	# a little per-instance tint variety so a crowd of 5-8 doesn't read
	# as identical clones.
	var tint := Color(randf_range(0.85, 1.15), randf_range(0.85, 1.15), randf_range(0.85, 1.15), 1)
	torso.color = Color(0.14, 0.3, 0.17, 1) * tint
	chest_strap.color = Color(0.07, 0.17, 0.09, 1) * tint
	mask.visible = false
	cap.visible = true
	_load_real_player_sprite(tint)
	name_tag.visible = true
	name_tag.text = GameManager.LEADERBOARD_NAMES[randi() % GameManager.LEADERBOARD_NAMES.size()]
	name_tag.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))
	_pick_new_roam_target()
	_pick_new_look_angle()
	_attach_weapon_icon()
	shoot_check_timer = randf_range(0.0, SHOOT_CHECK_INTERVAL)

# Same real_player art Enemy.gd's Arena opponents use - this script is
# set_script()'d onto an Enemy.tscn instance, so it never runs Enemy.gd's
# own _ready()/_try_load_external_sprite(). Reuses the same per-instance
# tint already computed for the vector fallback so both paths stay in sync.
func _load_real_player_sprite(tint: Color) -> void:
	if not ResourceLoader.exists("res://assets/enemy_real_player.png"):
		return
	var tex: Texture2D = load("res://assets/enemy_real_player.png")
	if tex == null:
		return
	external_sprite.texture = tex
	external_sprite.visible = true
	external_sprite.modulate = tint
	for n in ["LeftLeg", "RightLeg", "Torso", "ChestStrap", "Head", "Mask", "Cap", "TorsoOutline", "HeadOutline"]:
		var node = get_node_or_null("Visuals/" + n)
		if node:
			node.visible = false

# A random weapon icon (reusing the same procedurally-drawn icons the
# inventory uses) pinned near the gun hand, purely cosmetic - gives each
# NPC a visually distinct loadout without needing new weapon art.
func _attach_weapon_icon() -> void:
	var icon = ItemIconScene.instantiate()
	icon.icon_key = WEAPON_ICON_KEYS[randi() % WEAPON_ICON_KEYS.size()]
	icon.icon_color = Color(0.75, 0.75, 0.8, 1)
	icon.custom_minimum_size = Vector2(20, 20)
	icon.size = Vector2(20, 20)
	icon.position = Vector2(16, -6)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gun_pivot.add_child(icon)

func _pick_new_roam_target() -> void:
	var ang := randf_range(0.0, TAU)
	var dist := randf_range(20.0, ROAM_RADIUS)
	roam_target = origin + Vector2(cos(ang), sin(ang)) * dist
	roam_timer = randf_range(3.0, 6.0)

func _pick_new_look_angle() -> void:
	look_angle = randf_range(0.0, TAU)
	look_timer = randf_range(LOOK_AROUND_INTERVAL_MIN, LOOK_AROUND_INTERVAL_MAX)

func _physics_process(delta: float) -> void:
	roam_timer -= delta
	if roam_timer <= 0.0:
		_pick_new_roam_target()
	var dist := global_position.distance_to(roam_target)
	var moving: bool = dist > 10.0
	if moving:
		var dir := (roam_target - global_position).normalized()
		velocity = velocity.lerp(dir * BASE_SPEED, clamp(delta * 4.0, 0.0, 1.0))
	else:
		velocity = velocity.lerp(Vector2.ZERO, clamp(delta * 4.0, 0.0, 1.0))
	move_and_slide()
	walk_cycle += delta * 6.0
	if velocity.length() > 5.0:
		left_leg.position.y = 16 + sin(walk_cycle) * 3.0
		right_leg.position.y = 16 + sin(walk_cycle + PI) * 3.0
	else:
		left_leg.position.y = 16
		right_leg.position.y = 16

	# "Looking around" - while not actively walking somewhere, slowly
	# swing the gun/gaze toward a fresh random angle every couple of
	# seconds, like idly scanning the room instead of staring fixed.
	look_timer -= delta
	if look_timer <= 0.0:
		_pick_new_look_angle()
	if moving:
		gun_pivot.rotation = velocity.angle()
	else:
		gun_pivot.rotation = lerp_angle(gun_pivot.rotation, look_angle, clamp(delta * 2.0, 0.0, 1.0))

	_maybe_shoot(delta)
	_maybe_chat_on_proximity()

# Occasional cosmetic gunfire - a muzzle flash plus a real bullet fired
# in whatever direction they're currently looking, purely for ambience.
# Safe by construction: these NPCs never join "enemy" or "player", and
# Bullet.gd only ever damages "enemy"-group bodies, so this can't hit
# the real player or any other NPC here.
func _maybe_shoot(delta: float) -> void:
	shoot_check_timer -= delta
	if shoot_check_timer > 0.0:
		return
	shoot_check_timer = SHOOT_CHECK_INTERVAL
	if randf() >= SHOOT_CHANCE_PER_CHECK:
		return
	var dir := Vector2.RIGHT.rotated(gun_pivot.rotation)
	var bullet = BulletScene.instantiate()
	bullet.direction = dir
	bullet.is_enemy_bullet = false
	bullet.damage = 0
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	muzzle_flash.visible = true
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false

# A speech bubble whenever the player wanders close, same floating-Label
# pattern ArenaAlly.gd uses for its constant chatter - here it's gated
# on proximity + a cooldown instead of firing nonstop.
func _maybe_chat_on_proximity() -> void:
	if Time.get_ticks_msec() < chat_cooldown_until_ms:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > CHAT_RANGE:
		return
	chat_cooldown_until_ms = Time.get_ticks_msec() + int(CHAT_COOLDOWN_SECONDS * 1000.0)
	var bubble := Label.new()
	bubble.text = CHAT_LINES[randi() % CHAT_LINES.size()]
	bubble.add_theme_font_size_override("font_size", 12)
	bubble.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	bubble.add_theme_constant_override("outline_size", 3)
	bubble.position = Vector2(-30, -92)
	add_child(bubble)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw.tween_callback(bubble.queue_free)
