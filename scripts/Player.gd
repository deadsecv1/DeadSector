class_name Player
extends CharacterBody2D

signal health_changed(current: int, max_health: int)
signal stats_ready(speed: float, max_health: int, damage: int, shoot_cooldown: float)
signal died

@export var base_speed: float = 220.0
@export var base_max_health: int = 100
@export var base_shoot_cooldown: float = 0.25
@export var base_damage: int = 10

var speed: float
var max_health: int
var shoot_cooldown: float
var damage: int
var health_regen_rate: float = 0.0

var health: int
var can_shoot: bool = true
var alive: bool = true

# Concealment: set by Bush.gd while the player overlaps a bush. Enemies
# detect from much closer range, AND the player visually fades out so you
# can't see yourself either - matches actually hiding in cover.
var in_bush: bool = false

func set_in_bush(value: bool) -> void:
	if value == in_bush:
		return
	in_bush = value
	if value:
		Sfx.play_bush()

var walk_cycle: float = 0.0
var recoil: float = 0.0
var footstep_timer: float = 0.0
var regen_accumulator: float = 0.0

# Set true by HUD while the Backpack/TAB screen is open, so dragging loot
# around doesn't also move or fire the weapon.
var input_locked: bool = false

func set_input_locked(value: bool) -> void:
	input_locked = value

# --- In-raid chat speech bubble: shows "..." the moment the player
# opens the chat box, swaps to the real text once sent (held 2s, then
# fades over 2s), or fades the "..." over 2s if they cancel instead of
# sending. One bubble instance reused across all three states rather
# than recreated each time.
var _chat_bubble: Label = null
var _chat_bubble_tween: Tween = null

func _ensure_chat_bubble() -> Label:
	if _chat_bubble == null or not is_instance_valid(_chat_bubble):
		_chat_bubble = Label.new()
		_chat_bubble.add_theme_font_size_override("font_size", 12)
		_chat_bubble.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		_chat_bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_chat_bubble.add_theme_constant_override("outline_size", 3)
		_chat_bubble.custom_minimum_size = Vector2(90, 0)
		_chat_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chat_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
		_chat_bubble.position = Vector2(-45, -92)
		add_child(_chat_bubble)
	return _chat_bubble

func _kill_chat_bubble_tween() -> void:
	if _chat_bubble_tween != null and _chat_bubble_tween.is_valid():
		_chat_bubble_tween.kill()
	_chat_bubble_tween = null

func show_chat_typing_bubble() -> void:
	_kill_chat_bubble_tween()
	var bubble := _ensure_chat_bubble()
	bubble.text = "..."
	bubble.modulate.a = 1.0

func send_chat_message(text: String) -> void:
	_kill_chat_bubble_tween()
	var bubble := _ensure_chat_bubble()
	bubble.text = text
	bubble.modulate.a = 1.0
	_chat_bubble_tween = create_tween()
	_chat_bubble_tween.tween_interval(2.0)
	_chat_bubble_tween.tween_property(bubble, "modulate:a", 0.0, 2.0)
	_chat_bubble_tween.tween_callback(func():
		if is_instance_valid(bubble):
			bubble.queue_free()
		_chat_bubble = null
	)

func cancel_chat_typing() -> void:
	if _chat_bubble == null or not is_instance_valid(_chat_bubble):
		return
	_kill_chat_bubble_tween()
	var bubble := _chat_bubble
	_chat_bubble_tween = create_tween()
	_chat_bubble_tween.tween_property(bubble, "modulate:a", 0.0, 2.0)
	_chat_bubble_tween.tween_callback(func():
		if is_instance_valid(bubble):
			bubble.queue_free()
		_chat_bubble = null
	)

@onready var visuals: Node2D = $Visuals
@onready var health_bar: Node2D = $HealthBar
@onready var external_sprite: Sprite2D = $Visuals/ExternalSprite
@onready var camera: Camera2D = $Camera2D
@onready var gun_pivot: Node2D = $Visuals/GunPivot
@onready var flashlight: PointLight2D = $Visuals/GunPivot/FlashlightLight2D
@onready var gun_visual: Node2D = $Visuals/GunPivot/GunVisual
@onready var external_gun_sprite: Sprite2D = $Visuals/GunPivot/ExternalGunSprite
@onready var muzzle: Marker2D = $Visuals/GunPivot/GunVisual/Muzzle
@onready var muzzle_flash: Polygon2D = $Visuals/GunPivot/GunVisual/MuzzleFlash
@onready var left_leg: Polygon2D = $Visuals/LeftLeg
@onready var right_leg: Polygon2D = $Visuals/RightLeg
@onready var torso: Polygon2D = $Visuals/Torso
@onready var head: Polygon2D = $Visuals/Head
@onready var hair_cap: Polygon2D = $Visuals/HairCap
@onready var helmet: Polygon2D = $Visuals/Helmet
@onready var backpack_shape: Polygon2D = $Visuals/BackpackShape
@onready var accessory_glow: Polygon2D = $Visuals/AccessoryGlow
@onready var held_item_icon = $Visuals/HeldItemIcon
@onready var laser_line: Line2D = $LaserLine
@onready var trajectory_line: Line2D = $TrajectoryLine
@onready var ammo_bar = $AmmoBar

var weapon_icon: String = "pistol"

# --- Ammo / reload ---
signal ammo_changed(current_mag: int, mag_size: int, reserve_ammo: int, ammo_type: String)
signal stunned(duration: float)
var stun_speed_mult: float = 1.0

func _update_ammo_display() -> void:
	ammo_changed.emit(current_mag, mag_size, _current_reserve(), _current_ammo_type())
	ammo_bar.update_ammo(current_mag, mag_size)
var mag_size: int = 12
var current_mag: int = 12
var is_reloading: bool = false
var _last_weapon_icon: String = ""
var _r_was_down: bool = false

# Reserve ammo isn't a hidden counter anymore - it's just however many
# rounds of the matching type are actually sitting in the Backpack right
# now, same as any other stacking inventory item.
func _current_ammo_type() -> String:
	return GameManager.get_ammo_type_for_weapon_item(GameManager.equipped_items.get("weapon"))

func _current_reserve() -> int:
	return GameManager.get_backpack_ammo_amount(_current_ammo_type())

# --- Sniper scope: hold right-click with a sniper rifle equipped AND a
# scope attachment installed to zoom in. Movement slows while scoped, like
# most extraction shooters, so it's a real tradeoff rather than a free
# zoom button.
var is_scoped: bool = false
const SCOPE_ZOOM := Vector2(0.42, 0.42)
const DEFAULT_ZOOM := Vector2(1.0, 1.0)
const SCOPED_SPEED_MULT := 0.4
const PRONE_SPEED_MULT := 0.5
var is_prone: bool = false
var is_on_ice: bool = false
var hazard_speed_mult: float = 1.0
var _slow_sources: int = 0
var _ice_sources: int = 0
var _prone_key_was_down: bool = false

const BODY_COLOR_DEFAULT := Color(0.18, 0.42, 0.75, 1)
const BODY_COLOR_ARMORED := Color(0.3, 0.32, 0.28, 1)
const LEG_COLOR_DEFAULT := Color(0.16, 0.16, 0.2, 1)
const LEG_COLOR_BOOTED := Color(0.32, 0.22, 0.12, 1)

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")
const GRENADE_SCENE := preload("res://scenes/Grenade.tscn")
const SMOKE_GRENADE_SCENE := preload("res://scenes/SmokeGrenade.tscn")
const STUN_GRENADE_SCENE := preload("res://scenes/StunGrenade.tscn")
const FIRE_GRENADE_SCENE := preload("res://scenes/FireGrenade.tscn")

func _ready() -> void:
	add_to_group("player")
	_try_load_external_sprite()
	visuals.scale.x = lerp(0.8, 1.28, GameManager.player_build)
	if GameManager.player_skin_color_idx >= 0 and GameManager.player_skin_color_idx < GameManager.SKIN_COLORS.size():
		head.color = GameManager.SKIN_COLORS[GameManager.player_skin_color_idx]
	if GameManager.player_hair_color_idx >= 0 and GameManager.player_hair_color_idx < GameManager.HAIR_COLORS.size():
		hair_cap.color = GameManager.HAIR_COLORS[GameManager.player_hair_color_idx]
	_build_particle_trail()
	GameManager.snapshot_equipped_for_run()
	GameManager.equipped_changed.connect(_recompute_stats)
	_recompute_stats()
	health = max_health
	health_changed.emit(health, max_health)
	health_bar.update_health(health, max_health)

# --- Optional external art: if res://assets/player.png exists, use it
# instead of the built-in vector body. Drop your own art there any time -
# no code changes needed. Falls back to vector art if the file is missing.
#
# Only the base body shapes are hidden here - the gun and the
# helmet/backpack/accessory overlays are separate pieces drawn on top
# of the body, not replaced by it, so they keep working normally and
# still change dynamically with equipped weapon/gear.
func _try_load_external_sprite() -> void:
	var path := "res://assets/player.png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	external_sprite.texture = tex
	external_sprite.visible = true
	left_leg.visible = false
	right_leg.visible = false
	torso.visible = false
	head.visible = false
	hair_cap.visible = false
	get_node("Visuals/TorsoOutline").visible = false
	get_node("Visuals/HeadOutline").visible = false
	get_node("Visuals/ChestStrap").visible = false

# --- Cosmetic Particle Trail: dust motes, dripping shadow smoke, or
# crackling static. Built here (not in the .tscn) since the look varies
# a lot by style - easier to configure one CPUParticles2D in code per
# style than hand-tune three separate presets in the scene file. Player
# is instanced identically for both raids and the Hideout, so this one
# spot covers both automatically.
var _trail_particles: CPUParticles2D = null

func _build_particle_trail() -> void:
	var style: String = GameManager.player_particle_trail
	if style == "none" or style == "":
		return
	_trail_particles = CPUParticles2D.new()
	_trail_particles.position = Vector2(0, 10)
	_trail_particles.z_index = -1
	add_child(_trail_particles)
	_trail_particles.emitting = true
	_trail_particles.amount = 24
	_trail_particles.lifetime = 1.1
	_trail_particles.preprocess = 1.0
	match style:
		"dust":
			_trail_particles.direction = Vector2(0, -1)
			_trail_particles.spread = 40.0
			_trail_particles.gravity = Vector2(0, -6)
			_trail_particles.initial_velocity_min = 4.0
			_trail_particles.initial_velocity_max = 14.0
			_trail_particles.scale_amount_min = 1.2
			_trail_particles.scale_amount_max = 2.6
			_trail_particles.color = Color(0.85, 0.8, 0.65, 0.55)
			_trail_particles.amount = 18
			_trail_particles.lifetime = 1.6
		"shadow_smoke":
			_trail_particles.direction = Vector2(0, -1)
			_trail_particles.spread = 25.0
			_trail_particles.gravity = Vector2(0, -14)
			_trail_particles.initial_velocity_min = 6.0
			_trail_particles.initial_velocity_max = 16.0
			_trail_particles.scale_amount_min = 2.5
			_trail_particles.scale_amount_max = 5.0
			_trail_particles.color = Color(0.15, 0.05, 0.2, 0.55)
			_trail_particles.amount = 20
			_trail_particles.lifetime = 1.3
		"static":
			_trail_particles.direction = Vector2(0, 0)
			_trail_particles.spread = 180.0
			_trail_particles.gravity = Vector2.ZERO
			_trail_particles.initial_velocity_min = 18.0
			_trail_particles.initial_velocity_max = 45.0
			_trail_particles.scale_amount_min = 0.8
			_trail_particles.scale_amount_max = 1.8
			_trail_particles.color = Color(0.6, 0.85, 1.0, 0.9)
			_trail_particles.amount = 16
			_trail_particles.lifetime = 0.35
			_trail_particles.explosiveness = 0.15

func _recompute_stats() -> void:
	# Apply stat bonuses from currently equipped gear, Skill Tree upgrades,
	# AND Hideout Gym training.
	var prev_max_health := max_health
	speed = base_speed + GameManager.get_equipped_bonus("speed") + GameManager.get_upgrade_bonus("speed") + GameManager.get_hideout_bonus("speed")
	max_health = base_max_health + int(GameManager.get_equipped_bonus("max_health") + GameManager.get_upgrade_bonus("max_health") + GameManager.get_hideout_bonus("max_health"))
	shoot_cooldown = max(0.08, base_shoot_cooldown - GameManager.get_equipped_bonus("fire_rate") - GameManager.get_upgrade_bonus("fire_rate"))
	damage = base_damage + int(GameManager.get_equipped_bonus("damage") + GameManager.get_upgrade_bonus("damage") + GameManager.get_upgrade_bonus("melee_damage") + GameManager.get_hideout_bonus("damage"))
	health_regen_rate = GameManager.get_equipped_bonus("health_regen") + GameManager.get_upgrade_bonus("health_regen") + GameManager.get_hideout_bonus("health_regen")

	vision_range = VISION_RANGE_BASE + GameManager.get_equipped_bonus("vision_range") + GameManager.get_upgrade_bonus("vision_range")
	if flashlight != null:
		flashlight.set_range(vision_range)

	# If max health just went up mid-run (equipped better armor), carry the
	# increase over to current health too, instead of leaving it unchanged.
	if prev_max_health > 0 and max_health != prev_max_health:
		health += (max_health - prev_max_health)
		health = clamp(health, 0, max_health)
		health_changed.emit(health, max_health)
	health_bar.update_health(health, max_health)

	var weapon_item = GameManager.equipped_items.get("weapon")
	weapon_icon = weapon_item.get("icon_key", "pistol") if weapon_item != null else "pistol"
	_apply_ammo_type_tradeoff(weapon_item)

	stats_ready.emit(speed, max_health, damage, shoot_cooldown)

	_recompute_ammo()
	_update_appearance()

# Heavier ammo hits harder but cycles slower; lighter ammo cycles faster
# but hits softer; medium is the neutral baseline - a real tradeoff tied
# to which reserve pool the equipped weapon draws from, not just cosmetic.
const AMMO_DAMAGE_MULT := {"light": 0.85, "medium": 1.0, "heavy": 1.2}
const AMMO_COOLDOWN_MULT := {"light": 0.85, "medium": 1.0, "heavy": 1.2}

func _apply_ammo_type_tradeoff(weapon_item) -> void:
	var ammo_type: String = GameManager.get_ammo_type_for_weapon_item(weapon_item)
	damage = int(round(damage * float(AMMO_DAMAGE_MULT.get(ammo_type, 1.0))))
	shoot_cooldown = max(0.08, shoot_cooldown * float(AMMO_COOLDOWN_MULT.get(ammo_type, 1.0)))

# --- Ammo: base capacity depends on weapon type, Extended Mag attachment
# adds a flat bonus. Swapping to a DIFFERENT weapon tops off a fresh mag
# and reserve; installing/removing an attachment on the SAME weapon only
# resizes the cap without magically refilling it.
func _base_mag_for(icon: String) -> int:
	match icon:
		"pistol":
			return 18
		"rifle":
			return 45
		"sniper":
			return 9
		"flamethrower":
			return 110
		"thorn":
			return 15
		"railgun":
			return 8
		"alpha_cannon":
			return 12
		_:
			return 18

# Base reload time per weapon, in seconds, before upgrade/hideout speed
# bonuses. Small mags (pistol, sniper, railgun) snap back in fast; big
# ones (rifle) take a beat longer to slot in; the flamethrower's tank is
# the slowest swap in the game, matching how much ammo it's replacing.
func _base_reload_for(icon: String) -> float:
	match icon:
		"pistol":
			return 0.85
		"rifle":
			return 1.4
		"shotgun":
			return 1.6
		"sniper":
			return 1.1
		"flamethrower":
			return 2.2
		"thorn":
			return 1.3
		"railgun":
			return 1.0
		"alpha_cannon":
			return 1.5
		_:
			return 1.2

var _ammo_bonus_applied: bool = false

func _recompute_ammo() -> void:
	if not _ammo_bonus_applied:
		# Pack Mule (Skill Tree) grants +Reserve Ammo, and now some gear
		# can too - applied once, at raid start, as real Ammo items
		# dropped straight into the Backpack (split evenly across all 3
		# types), since reserve ammo is real inventory now rather than a
		# hidden counter (this function re-runs on every gear swap via
		# equipped_changed, so adding it unconditionally would let
		# re-equipping something farm free ammo).
		_ammo_bonus_applied = true
		var bonus: int = int((GameManager.get_upgrade_bonus("ammo_reserve") + GameManager.get_equipped_bonus("ammo_reserve")) / 3.0)
		if bonus > 0:
			for ammo_type in ["light", "medium", "heavy"]:
				GameManager.add_loot({
					"name": "%s Ammo x%d" % [ammo_type.capitalize(), bonus],
					"base_name": "%s Ammo" % ammo_type.capitalize(),
					"value": max(1, bonus / 3), "slot": "ammo", "icon_key": "ammo_%s" % ammo_type,
					"rarity": "common", "consumable_type": "ammo", "ammo_type": ammo_type, "ammo_amount": bonus,
				})
	var base_mag := _base_mag_for(weapon_icon)
	var mag_bonus := 0
	var weapon = GameManager.equipped_items.get("weapon")
	if weapon != null and weapon.has("attachments"):
		var mag_att = weapon["attachments"].get("mag")
		if mag_att != null:
			mag_bonus = 10
	var new_size: int = base_mag + mag_bonus
	if weapon_icon != _last_weapon_icon:
		# Switching weapons still tops off the magazine (a fresh weapon
		# starts loaded), but reserve ammo is per-type now and carries
		# over between weapons that share a type instead of resetting.
		mag_size = new_size
		current_mag = mag_size
		_last_weapon_icon = weapon_icon
	else:
		mag_size = new_size
		current_mag = min(current_mag, mag_size)
	_update_ammo_display()

# Changes how the character LOOKS based on what's currently equipped:
# a helmet appears if Head is filled, torso/legs recolor for Body/Boots,
# a pack appears on the back for Backpack, a small glow for Accessory, and
# the gun barrel lengthens for a rifle-type Weapon. All done with the
# existing vector shapes - no new art needed. If external art
# (res://assets/player.png) is active, the base-body recolor is skipped
# (there's no torso/legs to recolor - the sprite fills that role), but
# the helmet/backpack/accessory/gun overlays are separate pieces drawn
# on top of the body and keep updating normally either way.
#
# A purchased Skin (from the Store) always wins if one's equipped for
# that icon_key - that's a deliberate player choice. Otherwise, gear
# now tints toward its own rarity color instead of sitting plain white,
# so a Legendary/Mythic/Exotic piece visibly reads as such on your
# actual character, not just in the inventory grid. The tint strength
# scales with rarity - Common is untinted, Multiversal is strongly
# tinted - so it reads as "better gear looks more distinct" rather than
# every item getting an arbitrary paint job.
func _gear_tint(item, icon_key: String) -> Color:
	var skin_color: Color = GameManager.get_equipped_skin_color(icon_key)
	if skin_color != Color.WHITE:
		return skin_color
	if item == null:
		return Color.WHITE
	var rarity: String = String(item.get("rarity", "common"))
	var mult: float = GameManager.get_rarity_multiplier(rarity)
	var blend: float = clamp((mult - 1.0) / 9.0, 0.0, 1.0) * 0.6
	return Color.WHITE.lerp(GameManager.get_rarity_color(rarity), blend)

func _update_appearance() -> void:
	var equipped: Dictionary = GameManager.equipped_items
	var using_external: bool = external_sprite.visible

	var head_item = equipped.get("head")
	helmet.visible = head_item != null
	hair_cap.visible = not helmet.visible and not using_external
	helmet.modulate = _gear_tint(head_item, String(head_item.get("icon_key", "helmet"))) if head_item != null else Color.WHITE

	if not using_external:
		var body_item = equipped.get("body")
		torso.color = BODY_COLOR_ARMORED if body_item != null else BODY_COLOR_DEFAULT
		torso.modulate = _gear_tint(body_item, String(body_item.get("icon_key", "chestplate"))) if body_item != null else Color.WHITE
		torso.scale.x = 1.2 if GameManager.player_torso_style == "bulky" else (1.1 if GameManager.player_torso_style == "tactical" else 1.0)

		var boots_item = equipped.get("boots")
		var boots_on: bool = boots_item != null
		var boots_tint: Color = _gear_tint(boots_item, String(boots_item.get("icon_key", "boots"))) if boots_on else Color.WHITE
		left_leg.color = LEG_COLOR_BOOTED if boots_on else LEG_COLOR_DEFAULT
		right_leg.color = LEG_COLOR_BOOTED if boots_on else LEG_COLOR_DEFAULT
		left_leg.modulate = boots_tint
		right_leg.modulate = boots_tint

	backpack_shape.visible = equipped.get("backpack") != null
	if backpack_shape.visible:
		var pack_scale: float = 1.3 if GameManager.player_backpack_style == "massive_pack" else (0.85 if GameManager.player_backpack_style == "sleek_rig" else 1.0)
		backpack_shape.scale = Vector2(pack_scale, pack_scale)

	accessory_glow.visible = equipped.get("accessory") != null
	if accessory_glow.visible:
		var glow_idx: int = GameManager.player_glow_color_idx
		if glow_idx >= 0 and glow_idx < GameManager.GLOW_COLORS.size():
			accessory_glow.color = GameManager.GLOW_COLORS[glow_idx]["color"]

	if weapon_icon == "rifle":
		gun_visual.scale = Vector2(1.35, 1.0)
	elif weapon_icon == "sniper":
		gun_visual.scale = Vector2(1.65, 1.0)
	elif weapon_icon == "flamethrower":
		gun_visual.scale = Vector2(1.5, 1.2)
	elif weapon_icon == "thorn":
		gun_visual.scale = Vector2(1.2, 1.0)
	elif weapon_icon == "railgun":
		gun_visual.scale = Vector2(1.7, 1.15)
	elif weapon_icon == "alpha_cannon":
		gun_visual.scale = Vector2(1.9, 1.3)
	else:
		gun_visual.scale = Vector2(1.0, 1.0)

	gun_visual.modulate = _gear_tint(equipped.get("weapon"), weapon_icon)
	_update_external_gun_sprite()

# Checks for real weapon art at res://assets/weapons/<weapon_icon>.png -
# if found, shows that instead of the vector gun shape and swaps
# automatically whenever the equipped weapon type changes. Falls back
# to the vector gun for any weapon type without dedicated art.
var _gun_sprite_cache: Dictionary = {}

func _update_external_gun_sprite() -> void:
	# weapon_icon defaults to "pistol" even when nothing's actually
	# equipped (that default is only meant for the Hotbar's cosmetic
	# fallback icon) - without this check the gun visual would draw a
	# pistol regardless, instead of showing empty hands while unarmed.
	if GameManager.equipped_items.get("weapon") == null:
		external_gun_sprite.visible = false
		gun_visual.visible = false
		return
	var path := "res://assets/weapons/%s.png" % weapon_icon
	if not ResourceLoader.exists(path):
		external_gun_sprite.visible = false
		gun_visual.visible = true
		return
	if not _gun_sprite_cache.has(weapon_icon):
		_gun_sprite_cache[weapon_icon] = load(path)
	external_gun_sprite.texture = _gun_sprite_cache[weapon_icon]
	external_gun_sprite.modulate = _gear_tint(GameManager.equipped_items.get("weapon"), weapon_icon)
	external_gun_sprite.visible = true
	gun_visual.visible = false

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_handle_regen(delta)
	if input_locked:
		velocity = velocity.lerp(Vector2.ZERO, clamp(delta * 12.0, 0.0, 1.0))
		move_and_slide()
		is_scoped = false
		camera.zoom = camera.zoom.lerp(DEFAULT_ZOOM, clamp(delta * 9.0, 0.0, 1.0))
		laser_line.visible = false
		trajectory_line.visible = false
		is_aiming_grenade = false
		_animate(delta)
		return
	_handle_movement(delta)
	_handle_aim()
	_handle_body_turn(delta)
	_handle_shoot()
	_handle_reload_input()
	_handle_scope(delta)
	_handle_jump_dash_nightvision(delta)
	GameManager.check_vicinity_leash(global_position)
	_update_held_item()
	_update_laser()
	_animate(delta)

const DASH_COOLDOWN := 3.0
const DASH_SPEED := 900.0
const DASH_DURATION := 0.16
var _jump_was_down: bool = false
var _dash_was_down: bool = false
var _nightvision_was_down: bool = false
var dash_cooldown_left: float = 0.0
var dash_time_left: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var nightvision_active: bool = false

func _handle_jump_dash_nightvision(delta: float) -> void:
	if dash_cooldown_left > 0.0:
		dash_cooldown_left -= delta
	if dash_time_left > 0.0:
		dash_time_left -= delta
		velocity = dash_direction * DASH_SPEED

	var jump_down := Input.is_key_pressed(GameManager.get_keybind("jump"))
	if jump_down and not _jump_was_down:
		_do_jump_hop()
	_jump_was_down = jump_down

	var dash_down := Input.is_key_pressed(GameManager.get_keybind("dash"))
	if dash_down and not _dash_was_down and dash_cooldown_left <= 0.0:
		_do_dash()
	_dash_was_down = dash_down

	var nv_down := Input.is_key_pressed(GameManager.get_keybind("nightvision"))
	if nv_down and not _nightvision_was_down:
		_toggle_nightvision()
	_nightvision_was_down = nv_down

func _do_jump_hop() -> void:
	# Purely cosmetic in a top-down game - a quick squash-and-stretch hop
	# so pressing the key still feels like it did something real.
	var hop_tw := create_tween()
	hop_tw.tween_property(visuals, "scale", Vector2(0.85, 1.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_tw.tween_property(visuals, "scale", Vector2(1.1, 0.9), 0.1).set_trans(Tween.TRANS_QUAD)
	hop_tw.tween_property(visuals, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _do_dash() -> void:
	var dir := velocity.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(cos(gun_pivot.rotation), sin(gun_pivot.rotation))
	dash_direction = dir
	dash_time_left = DASH_DURATION
	dash_cooldown_left = DASH_COOLDOWN
	camera.shake(3.0)
	modulate.a = 0.55
	var dash_tw := create_tween()
	dash_tw.tween_property(self, "modulate:a", 1.0, DASH_DURATION + 0.1)

func _toggle_nightvision() -> void:
	var attachment = GameManager.equipped_items.get("helmet_attachment")
	if attachment == null or not attachment.get("grants_nightvision", false):
		GameManager.toast_requested.emit("No Nightvision Goggles equipped")
		return
	nightvision_active = not nightvision_active
	Sfx.play_nightvision_toggle()

func _handle_regen(delta: float) -> void:
	var rate := health_regen_rate
	if rate <= 0.0 or health >= max_health:
		regen_accumulator = 0.0
		return
	regen_accumulator += rate * delta
	if regen_accumulator >= 1.0:
		var heal := int(regen_accumulator)
		health = min(health + heal, max_health)
		regen_accumulator -= heal
		health_changed.emit(health, max_health)
		health_bar.update_health(health, max_health)

func _handle_movement(delta: float) -> void:
	var prone_key := GameManager.get_keybind("prone")
	var prone_down := Input.is_key_pressed(prone_key)
	if prone_down and not _prone_key_was_down:
		is_prone = not is_prone
		var target_scale: Vector2 = Vector2(1.15, 0.55) if is_prone else Vector2(1.0, 1.0)
		var prone_tw := create_tween()
		prone_tw.tween_property(visuals, "scale", target_scale, 0.2).set_trans(Tween.TRANS_QUAD)
	_prone_key_was_down = prone_down

	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	dir = dir.normalized()
	var prone_mult: float = PRONE_SPEED_MULT if is_prone else 1.0
	var adrenaline_mult: float = 1.3 if (GameManager.player_trait == "adrenaline_junkie" and health < max_health * 0.3) else 1.0
	var target_speed := speed * (SCOPED_SPEED_MULT if is_scoped else 1.0) * stun_speed_mult * prone_mult * hazard_speed_mult * adrenaline_mult
	# Lerp toward the target velocity instead of snapping, so the character
	# slides slightly to a stop rather than freezing instantly. On ice,
	# the lerp is much slower - velocity barely responds to new input,
	# so momentum carries you across the patch instead of turning cleanly.
	var control_rate: float = 3.0 if is_on_ice else 12.0
	velocity = velocity.lerp(dir * target_speed, clamp(delta * control_rate, 0.0, 1.0))
	move_and_slide()

# Reference-counted like set_slowed() below, not a plain toggle - overlapping
# ice patches (common along a frost bullet's trail) used to end the slide
# the instant you left ANY one of them, even while still standing on
# another. Same public API, so IcePatch.gd needs no changes.
func set_on_ice(value: bool) -> void:
	_ice_sources = max(0, _ice_sources + (1 if value else -1))
	is_on_ice = _ice_sources > 0

var _flashlight_disabled: bool = false

func disable_flashlight(duration: float) -> void:
	if flashlight == null:
		return
	_flashlight_disabled = true
	flashlight.enabled = false
	GameManager.toast_requested.emit("Flashlight scrambled!")
	await get_tree().create_timer(duration).timeout
	_flashlight_disabled = false
	if flashlight != null and is_instance_valid(self):
		flashlight.enabled = true

func set_slowed(value: bool) -> void:
	_slow_sources = max(0, _slow_sources + (1 if value else -1))
	hazard_speed_mult = 0.5 if _slow_sources > 0 else 1.0

func _handle_aim() -> void:
	gun_pivot.look_at(get_global_mouse_position())

# Turns the whole body smoothly to face wherever the cursor is - the gun
# itself snaps instantly (it has to, for accurate aim), but the body
# eases into the turn so it reads as a natural pivot instead of a
# robotic snap. Applies to both the vector body and any external sprite,
# since both live under the same Visuals node.
#
# Computed as the direct global angle to the mouse rather than copying
# gun_pivot's rotation - gun_pivot is a child of Visuals, so its local
# rotation is relative to Visuals's own rotation and would make a
# moving, self-referential target if used directly here.
const BODY_TURN_SPEED := 11.0

func _handle_body_turn(delta: float) -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 1.0:
		return
	var target_angle: float = to_mouse.angle()
	visuals.rotation = lerp_angle(visuals.rotation, target_angle, clamp(delta * BODY_TURN_SPEED, 0.0, 1.0))

# Real fog-of-war check: is this point inside the flashlight cone (or close
# enough to always be visible regardless of aim)? Matches Flashlight.gd's
# own cone_angle_deg/light_range so what you SEE matches what's lit.
const VISION_CONE_DEG := 34.0
const VISION_RANGE_BASE := 460.0
const VISION_CLOSE_RADIUS := 100.0
var vision_range: float = VISION_RANGE_BASE

func can_see_point(world_pos: Vector2) -> bool:
	var to_point := world_pos - global_position
	var dist := to_point.length()
	if dist <= VISION_CLOSE_RADIUS:
		return true
	if dist > vision_range:
		return false
	var aim_dir := (get_global_mouse_position() - global_position).normalized()
	var angle: float = abs(aim_dir.angle_to(to_point.normalized()))
	return angle <= deg_to_rad(VISION_CONE_DEG)

var _lmb_was_down: bool = false
var is_aiming_grenade: bool = false

func _handle_shoot() -> void:
	var lmb_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

	if GameManager.active_hotbar_slot == 0:
		is_aiming_grenade = false
		trajectory_line.visible = false
		# Nothing here previously checked whether a weapon was actually
		# equipped - current_mag/can_shoot still worked off the "pistol"
		# fallback icon used for cosmetic purposes when unarmed, so you
		# could still fire with no weapon equipped at all.
		if lmb_down and can_shoot and not is_reloading and GameManager.equipped_items.get("weapon") != null:
			if current_mag > 0:
				_shoot()
		_lmb_was_down = lmb_down
		return

	var entries := GameManager.get_consumable_entries()
	var slot_i := GameManager.active_hotbar_slot - 1
	if slot_i < 0 or slot_i >= entries.size():
		is_aiming_grenade = false
		trajectory_line.visible = false
		_lmb_was_down = lmb_down
		return

	var item: Dictionary = entries[slot_i]["item"]
	var ctype := String(item.get("consumable_type", ""))

	if ctype == "grenade":
		# Hold to aim (shows the throw line), release to actually throw it
		# at wherever the cursor is at that moment - instead of it just
		# going off wherever the mouse happened to be on a single click.
		if lmb_down:
			is_aiming_grenade = true
			trajectory_line.visible = true
			trajectory_line.points = PackedVector2Array([to_local(muzzle.global_position), to_local(get_global_mouse_position())])
		elif is_aiming_grenade:
			is_aiming_grenade = false
			trajectory_line.visible = false
			if can_shoot:
				_use_active_hotbar_item()
	else:
		is_aiming_grenade = false
		trajectory_line.visible = false
		if lmb_down and not _lmb_was_down and can_shoot:
			_use_active_hotbar_item()

	_lmb_was_down = lmb_down

# --- Reload (R key). Locks firing for the reload duration, then tops the
# mag off from reserve ammo. ---
func _handle_reload_input() -> void:
	var r_down := Input.is_key_pressed(KEY_R)
	if r_down and not _r_was_down and not is_reloading:
		if current_mag >= mag_size:
			pass
		elif _current_reserve() <= 0:
			var ammo_label: String = _current_ammo_type().capitalize()
			GameManager.toast_requested.emit("No %s Ammo left to reload with - find some more" % ammo_label)
		else:
			_start_reload()
	_r_was_down = r_down

func _start_reload() -> void:
	is_reloading = true
	can_shoot = false
	Sfx.play_reload()
	var duration: float = max(0.4, _base_reload_for(weapon_icon) - GameManager.get_equipped_bonus("reload_speed") - GameManager.get_upgrade_bonus("reload_speed") - GameManager.get_hideout_bonus("reload_speed"))
	await get_tree().create_timer(duration).timeout
	var ammo_type := _current_ammo_type()
	var needed := mag_size - current_mag
	var taken: int = GameManager.consume_backpack_ammo(ammo_type, needed)
	current_mag += taken
	_update_ammo_display()
	is_reloading = false
	can_shoot = true

# Grenades: called on release after aiming. Heal items: called on press.
# Either way, a small cooldown stops instantly re-triggering.
func _use_active_hotbar_item() -> void:
	var entries := GameManager.get_consumable_entries()
	var slot_i := GameManager.active_hotbar_slot - 1
	if slot_i < 0 or slot_i >= entries.size():
		return
	can_shoot = false
	var entry: Dictionary = entries[slot_i]
	var removed := GameManager.consume_carried_item(int(entry["index"]))
	if not removed.is_empty():
		apply_consumable(removed)
	await get_tree().create_timer(0.35).timeout
	can_shoot = true

# Shows whichever consumable is currently selected on the Hotbar near the
# character's hand, so it's visually obvious what left-click will do -
# hidden when the weapon slot (0) is active, since the gun itself is shown.
func _update_held_item() -> void:
	if GameManager.active_hotbar_slot == 0:
		held_item_icon.visible = false
		return
	var entries := GameManager.get_consumable_entries()
	var slot_i := GameManager.active_hotbar_slot - 1
	if slot_i < 0 or slot_i >= entries.size():
		held_item_icon.visible = false
		return
	var item: Dictionary = entries[slot_i]["item"]
	held_item_icon.icon_key = item.get("icon_key", "medkit")
	held_item_icon.visible = true
	held_item_icon.queue_redraw()

func _has_zoom_scope() -> bool:
	var weapon = GameManager.equipped_items.get("weapon")
	if weapon == null or not weapon.has("attachments"):
		return false
	var scope = weapon["attachments"].get("scope")
	return scope != null and bool(scope.get("enables_zoom", false))

func _has_laser_attachment() -> bool:
	var weapon = GameManager.equipped_items.get("weapon")
	if weapon == null or not weapon.has("attachments"):
		return false
	return weapon["attachments"].get("laser") != null

func _has_grip_attachment() -> bool:
	var weapon = GameManager.equipped_items.get("weapon")
	if weapon == null or not weapon.has("attachments"):
		return false
	return weapon["attachments"].get("grip") != null

# Draws a red laser line from the muzzle to the cursor while a Laser Sight
# is installed on the equipped weapon.
func _update_laser() -> void:
	if alive and _has_laser_attachment():
		laser_line.visible = true
		laser_line.points = PackedVector2Array([to_local(muzzle.global_position), to_local(get_global_mouse_position())])
	else:
		laser_line.visible = false

func _handle_scope(delta: float) -> void:
	var wants_scope := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and weapon_icon == "sniper" and _has_zoom_scope()
	is_scoped = wants_scope

	var target_zoom := DEFAULT_ZOOM
	if wants_scope:
		target_zoom = SCOPE_ZOOM
	camera.zoom = camera.zoom.lerp(target_zoom, clamp(delta * 9.0, 0.0, 1.0))

var last_shot_time_ms: int = -999999
const GUNSHOT_NOISE_WINDOW_MS := 1200

# A recently-fired gunshot is loud enough that hiding in a bush stops
# mattering for a moment - staying still and quiet is what bushes are
# actually for. Used by Enemy.gd's detection range calculation.
func is_making_noise() -> bool:
	return Time.get_ticks_msec() - last_shot_time_ms < GUNSHOT_NOISE_WINDOW_MS

func _shoot() -> void:
	can_shoot = false
	last_shot_time_ms = Time.get_ticks_msec()
	var lucky_save: bool = GameManager.player_trait == "lucky_break" and randf() < 0.1
	if not lucky_save:
		current_mag -= 1
	_update_ammo_display()
	# Direction comes from the gun's actual aim rotation, not a fresh
	# muzzle-to-cursor vector - the muzzle sits some distance forward of
	# the character along the barrel, so when the cursor was closer to
	# the character than that offset, (cursor - muzzle_position) could
	# point backwards relative to where the gun was actually aimed,
	# firing the shot in the opposite direction. gun_pivot's rotation
	# is already correctly aimed every frame via look_at() in
	# _handle_aim() and doesn't have this problem.
	var base_dir: Vector2 = Vector2.RIGHT.rotated(gun_pivot.global_rotation)
	var base_angle: float = base_dir.angle()

	var equipped_weapon = GameManager.equipped_items.get("weapon")
	var weapon_rarity: String = str(equipped_weapon.get("rarity", "common")) if equipped_weapon != null else "common"
	var is_top_tier_weapon: bool = weapon_rarity in ["exotic", "multiversal", "divine"]
	var is_tech_tester_sidearm: bool = weapon_icon == "pistol" and equipped_weapon != null and equipped_weapon.get("beta_only", false)

	if weapon_icon == "shotgun":
		# A real spread of individual pellets instead of one bullet -
		# each one rolls its own damage and can hit separately, giving
		# shotguns their own distinct up-close, multi-hit identity.
		const PELLET_COUNT := 5
		const SPREAD_RADIANS := 0.32
		# Each pellet at 0.6x used to add up to 3.0x a normal shot's damage
		# if they all landed - by far the strongest weapon in the game at
		# close range. 0.32x per pellet (1.6x total on a full hit) still
		# rewards landing every pellet without being absurd.
		const PELLET_DAMAGE_MULT := 0.32
		for i in range(PELLET_COUNT):
			var t: float = (float(i) / float(PELLET_COUNT - 1)) - 0.5 if PELLET_COUNT > 1 else 0.0
			var pellet_angle: float = base_angle + t * SPREAD_RADIANS + randf_range(-0.03, 0.03)
			var pellet_dir := Vector2(cos(pellet_angle), sin(pellet_angle))
			_spawn_bullet(pellet_dir, PELLET_DAMAGE_MULT)
	elif is_tech_tester_sidearm:
		# Fires 3 projectiles in a tight spread instead of one - damage
		# per projectile is scaled down (0.5x) rather than full, since
		# this weapon's fire rate is already the fastest in the game;
		# without scaling it down, 3x the projectiles on top of an
		# already-absurd cooldown would make it wildly overtuned instead
		# of just visually cooler.
		const TECH_TESTER_SPREAD_RADIANS := 0.1
		for i in range(3):
			var t3: float = (float(i) / 2.0) - 0.5
			var tt_angle: float = base_angle + t3 * TECH_TESTER_SPREAD_RADIANS
			var tt_dir := Vector2(cos(tt_angle), sin(tt_angle))
			_spawn_bullet(tt_dir, 0.5)
	elif is_top_tier_weapon:
		# Exotic/Multiversal weapons fire a real multi-projectile burst
		# instead of one shot - a tighter spread than a shotgun (this is
		# about the weapon being exceptional, not a close-range weapon
		# type), with each projectile still hitting for close to full
		# damage rather than a shotgun's per-pellet split.
		var burst_count: int = randi_range(3, 5)
		const TOP_TIER_SPREAD_RADIANS := 0.14
		for i in range(burst_count):
			var t2: float = (float(i) / float(burst_count - 1)) - 0.5 if burst_count > 1 else 0.0
			var burst_angle: float = base_angle + t2 * TOP_TIER_SPREAD_RADIANS
			var burst_dir := Vector2(cos(burst_angle), sin(burst_angle))
			_spawn_bullet(burst_dir, 0.85)
	else:
		_spawn_bullet(base_dir, 1.0)

	recoil = -6.0
	_flash_muzzle()
	Sfx.play_gunshot()
	camera.shake(2.5 * (0.45 if _has_grip_attachment() else 1.0))
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

# Spawns a single bullet in the given direction. damage_mult lets a
# multi-pellet weapon (shotgun) roll several partial-damage hits
# instead of one full-damage hit.
func _spawn_bullet(dir: Vector2, damage_mult: float) -> void:
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = dir
	bullet.is_enemy_bullet = false
	# Small per-shot variance so damage numbers aren't identical every hit
	# (e.g. a 10-damage weapon might land 8-12), while staying close to the
	# weapon's real average damage over many shots.
	var shot_damage: float = float(max(1, damage + randi_range(-2, 2))) * damage_mult
	var is_crit: bool = randf() < GameManager.get_equipped_bonus("crit_chance") + GameManager.get_upgrade_bonus("crit_chance")
	if is_crit:
		shot_damage *= 1.5
	bullet.damage = int(round(shot_damage))
	bullet.is_crit = is_crit
	# The Tech Tester's Sidearm shares the plain "pistol" icon_key (so its
	# damage/reload logic below is unaffected), but at a beta-exclusive
	# legendary with an absurd fire rate it deserves to look like more
	# than a stock starter pistol - a distinct bullet style, checked by
	# beta_only rather than icon_key so it doesn't touch any other gun.
	# equipped_items["weapon"] is null (not absent) whenever nothing's
	# equipped, so .get("weapon", {}) returns that null itself rather
	# than the {} default - calling .get() on it crashed. Explicit
	# null-check instead, same as the equivalent check up in _shoot().
	var equipped_weapon_for_style = GameManager.equipped_items.get("weapon")
	var is_tech_tester_sidearm: bool = weapon_icon == "pistol" and equipped_weapon_for_style != null and equipped_weapon_for_style.get("beta_only", false)
	bullet.style = "tech_tester_sidearm" if is_tech_tester_sidearm else weapon_icon
	if weapon_icon == "thorn":
		bullet.is_poison = true
		bullet.poison_damage = 4
		bullet.poison_duration = 4.0
	elif weapon_icon == "railgun":
		bullet.pierce_remaining = 2
		bullet.is_electric = true
	elif weapon_icon == "sniper":
		bullet.is_frost = true
	elif weapon_icon == "flamethrower":
		bullet.is_burning = true
	elif weapon_icon == "alpha_cannon":
		bullet.pierce_remaining = 4
		bullet.is_electric = true
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	if weapon_icon == "alpha_cannon":
		_spawn_alpha_cannon_muzzle_burst()

func _flash_muzzle() -> void:
	muzzle_flash.visible = true
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false

# A one-shot gold/prismatic particle burst at the muzzle, specific to
# the Alpha Cannon - reinforces that this weapon isn't like the others
# every time it fires, not just via the bullet's own trail.
func _spawn_alpha_cannon_muzzle_burst() -> void:
	var burst := CPUParticles2D.new()
	get_tree().current_scene.add_child(burst)
	burst.global_position = muzzle.global_position
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 14
	burst.lifetime = 0.35
	burst.explosiveness = 1.0
	burst.direction = Vector2.RIGHT.rotated(gun_pivot.global_rotation)
	burst.spread = 30.0
	burst.initial_velocity_min = 90.0
	burst.initial_velocity_max = 220.0
	burst.gravity = Vector2.ZERO
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.0
	burst.color = Color(1.0, 0.85, 0.4, 1)
	burst.emitting = true
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(burst):
			burst.queue_free()
	)

func _animate(delta: float) -> void:
	var move_amount: float = clamp(velocity.length() / max(speed, 1.0), 0.0, 1.0)
	if move_amount > 0.05:
		walk_cycle += delta * 12.0
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			Sfx.play_footstep()
			footstep_timer = 0.32
	else:
		footstep_timer = 0.0
	var amp := move_amount * 3.5

	left_leg.position = Vector2(-5.5, 17.5 + sin(walk_cycle) * amp)
	right_leg.position = Vector2(5.5, 17.5 + sin(walk_cycle + PI) * amp)

	var bob := sin(walk_cycle * 2.0) * amp * 0.25
	visuals.position = Vector2(0, bob)

	recoil = lerp(recoil, 0.0, delta * 14.0)
	gun_visual.position = Vector2(recoil, 0)

	# Fade out almost entirely while hiding in a bush.
	var target_alpha: float = 0.18 if in_bush else 1.0
	visuals.modulate.a = lerp(visuals.modulate.a, target_alpha, delta * 8.0)

var _second_wind_used: bool = false

# Whoever/whatever last actually landed a hit - read by GameManager right
# as a death is processed, so the Death Screen can say who got you and
# with what. Only overwritten when the caller actually names a source,
# so a later unattributed hit can't erase a real one.
var last_attacker_name: String = ""
var last_attacker_weapon: String = ""

func take_damage(amount: int, attacker_name: String = "", weapon_name: String = "") -> void:
	if not alive:
		return
	if attacker_name != "":
		last_attacker_name = attacker_name
		last_attacker_weapon = weapon_name
	# Armor: a new gear stat - flat percentage damage reduction, capped
	# well short of 100% so gear can meaningfully soften hits without
	# ever making the player fully immune to damage.
	var armor_pct: float = clamp(GameManager.get_equipped_bonus("armor"), 0.0, 60.0)
	if armor_pct > 0.0:
		amount = int(round(amount * (1.0 - armor_pct / 100.0)))
	health -= amount
	if health <= 0 and GameManager.player_trait == "second_wind" and not _second_wind_used:
		_second_wind_used = true
		health = 1
		GameManager.toast_requested.emit("Second Wind! Survived a killing blow at 1 HP.")
		health_changed.emit(health, max_health)
		health_bar.update_health(health, max_health)
		return
	health = max(health, 0)
	health_changed.emit(health, max_health)
	health_bar.update_health(health, max_health)
	if health <= 0:
		die()

func die() -> void:
	alive = false
	visible = false
	died.emit()
	GameManager.end_run(false)

# --- Hotbar consumables (heal / grenade). Called by Hotbar.gd after it
# removes the item from carried_loot via GameManager.consume_carried_item. ---
var _stun_token: int = 0

func apply_stun(duration: float) -> void:
	_stun_token += 1
	var my_token := _stun_token
	stunned.emit(duration)
	stun_speed_mult = 0.35
	await get_tree().create_timer(duration).timeout
	if my_token == _stun_token:
		stun_speed_mult = 1.0

func apply_consumable(item: Dictionary) -> void:
	var ctype := String(item.get("consumable_type", ""))
	if ctype == "heal":
		var amount := int(item.get("heal_amount", 30))
		health = min(health + amount, max_health)
		health_changed.emit(health, max_health)
		health_bar.update_health(health, max_health)
		Sfx.play_heal()
		GameManager.toast_requested.emit("Used %s (+%d HP)" % [item.get("name", "Bandage"), amount])
	elif ctype == "grenade":
		_throw_grenade(item)
		GameManager.toast_requested.emit("Threw %s" % item.get("name", "Grenade"))

func _throw_grenade(item: Dictionary) -> void:
	var gtype: String = item.get("grenade_type", "frag")
	var target := get_global_mouse_position()
	match gtype:
		"smoke":
			var smoke_g = SMOKE_GRENADE_SCENE.instantiate()
			smoke_g.global_position = muzzle.global_position
			smoke_g.target_position = target
			get_tree().current_scene.add_child(smoke_g)
		"stun":
			var stun_g = STUN_GRENADE_SCENE.instantiate()
			stun_g.global_position = muzzle.global_position
			stun_g.target_position = target
			get_tree().current_scene.add_child(stun_g)
		"molotov":
			var fire_g = FIRE_GRENADE_SCENE.instantiate()
			fire_g.global_position = muzzle.global_position
			fire_g.target_position = target
			get_tree().current_scene.add_child(fire_g)
		_:
			var frag_g = GRENADE_SCENE.instantiate()
			frag_g.global_position = muzzle.global_position
			frag_g.target_position = target
			var power_bonus: float = GameManager.get_upgrade_bonus("grenade_power")
			frag_g.damage = int(item.get("grenade_damage", 55)) + int(power_bonus)
			frag_g.radius = float(item.get("grenade_radius", 95.0)) + power_bonus
			get_tree().current_scene.add_child(frag_g)
