extends CharacterBody2D

signal died

@export var speed: float = 120.0
@export var max_health: int = 85
@export var enemy_type_id: String = ""
@export var use_external_sprite: bool = true
@export var detection_range: float = 480.0
@export var attack_range: float = 260.0
@export var shoot_cooldown: float = 1.2

# If set, this enemy drops a key on death that unlocks the matching door
# (a Door node with a matching key_id).
@export var drop_key_id: String = ""
@export var drop_key_label: String = "Key"

# Chance this enemy also drops a random gear item (from GameManager's
# ENEMY_LOOT_POOL) on death. This is the main source of gear out in the
# open world - the rest comes from vault rooms inside houses.
@export var loot_drop_chance: float = 0.4
@export var attack_damage: int = 20

# Set inside _ready() from GameManager.get_enemy_scaling_factor() - exposed
# so boss subclasses (Spike, Rattles) can scale their own special-attack
# damage (spike aura, thrown bones, grenades, custom bullets) the same way
# attack_damage already scales below. Bosses don't route those attacks
# through attack_damage at all, so without this they'd stay exactly as
# threatening at Level 1 as at max Skill Tree investment while their own
# HP keeps scaling up to compensate for the player's growing damage output.
var enemy_scale_factor: float = 1.0
const BOSS_DAMAGE_MULT := 1.1 # same rate regular attack_damage scales at

# The "Real Player" variant: a visually distinct, tougher enemy classified
# as a real player. Always drops Dog Tags on death.
@export var is_real_player: bool = false

# Cosmetic-only loadout for a Real Player - same shape as GameManager's
# equipped_items (slot -> item dict with icon_key/rarity). Never affects
# stats. Left empty here and auto-rolled in _ready() via GameManager.
# generate_random_enemy_gear() unless a spawner (e.g. TheGrid.gd's Arena
# matchmaking) assigns a specific one first.
var gear: Dictionary = {}

# Set true on the Spike boss scene - ties into the "Kill Spike" quest.
@export var is_boss: bool = false

# Rare mid-raid event enemy (see _maybe_spawn_elite_cache_event() in each
# raid map script) - tougher than a normal Raider, guarding a
# higher-value cache, but deliberately NOT is_boss: that flag fires the
# Spike-specific "kill_spike" quest event, which an elite guard has
# nothing to do with.
@export var is_elite_guard: bool = false
var is_on_ice: bool = false
var _ice_sources: int = 0

# Reference-counted, not a plain toggle - overlapping ice patches used to
# end the slide the instant this enemy left ANY one of them, even while
# still standing on another. Same public API, so IcePatch.gd needs no
# changes. Matches Player.gd's identical fix.
func set_on_ice(value: bool) -> void:
	_ice_sources = max(0, _ice_sources + (1 if value else -1))
	is_on_ice = _ice_sources > 0

func _ice_control_rate() -> float:
	return 3.0 if is_on_ice else 10.0

var health: int
var can_shoot: bool = true
var player: Player = null
var walk_cycle: float = 0.0
var recoil: float = 0.0
var _using_external_sprite: bool = false

# queue_free() only removes the node at end of frame, so without this
# guard a second take_damage() landing in the same frame (e.g. multiple
# shotgun pellets hitting at once) could re-enter die() and double-grant
# its kill credit, loot roll, and corpse spawn.
var is_dead: bool = false

# Real Player operators dash every 4-7 seconds - a quick burst of speed
# straight at (or past) you, on top of their normal chase movement.
var _dash_timer: float = 0.0
var _dash_active_time: float = 0.0
const DASH_SPEED_MULT := 3.2
const DASH_DURATION := 0.22

@onready var visuals: Node2D = $Visuals
@onready var external_sprite: Sprite2D = $Visuals/ExternalSprite
@onready var gun_pivot: Node2D = $Visuals/GunPivot
@onready var gun_visual: Node2D = $Visuals/GunPivot/GunVisual
@onready var muzzle: Marker2D = $Visuals/GunPivot/GunVisual/Muzzle
@onready var muzzle_flash: Polygon2D = $Visuals/GunPivot/GunVisual/MuzzleFlash
@onready var left_leg: Polygon2D = $Visuals/LeftLeg
@onready var right_leg: Polygon2D = $Visuals/RightLeg
@onready var torso: Polygon2D = $Visuals/Torso
@onready var chest_strap: Polygon2D = $Visuals/ChestStrap
@onready var mask: Polygon2D = $Visuals/Mask
@onready var cap: Polygon2D = $Visuals/Cap
# Real Player-only overlays (gear icons, weapon sprite swap). get_node_or_
# null() rather than $Path since the 11 typed-monster subclasses are each
# their own independent .tscn copy (not Godot scene inheritance) - they've
# all been given these same nodes too (so is_real_player can be set on
# any of them, e.g. Marauder's VoidTrench "TrenchMarauder1"), but nothing
# guarantees a *future* subclass gets them before someone sets
# is_real_player on it, and _apply_gear_visuals() below assumes non-null.
@onready var helmet_icon = get_node_or_null("Visuals/HelmetIcon")
@onready var backpack_icon = get_node_or_null("Visuals/BackpackIcon")
@onready var accessory_icon = get_node_or_null("Visuals/AccessoryIcon")
@onready var boots_icon = get_node_or_null("Visuals/BootsIcon")
@onready var external_gun_sprite: Sprite2D = get_node_or_null("Visuals/GunPivot/ExternalGunSprite")
@onready var name_tag: Label = $Visuals/NameTag
@onready var health_bar: ProgressBar = $Visuals/HealthBar

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")
const CORPSE_SCENE := preload("res://scenes/Corpse.tscn")

# Every enemy's position in the .tscn files is hand-placed, which meant
# the exact same enemy was always in the exact same spot every single
# raid - the map never actually felt different twice. Scattering a bit
# from that authored position at spawn keeps them roughly where they
# were designed to be (still guarding the same POI) while making the
# precise spot different every time. Bosses are excluded since their
# position is tied to their dedicated arena (barrels, fencing, etc.)
# built specifically around that one spot.
const SPAWN_JITTER_RADIUS := 220.0

func _apply_spawn_jitter() -> void:
	if is_boss:
		return
	var angle := randf() * TAU
	var dist := randf() * SPAWN_JITTER_RADIUS
	position += Vector2(cos(angle), sin(angle)) * dist

func _ready() -> void:
	add_to_group("enemy")
	_apply_spawn_jitter()
	_try_load_external_sprite()
	var scale_factor: float = GameManager.get_enemy_scaling_factor()
	enemy_scale_factor = scale_factor
	# Baseline difficulty bump - independent of the skill-progression
	# scaling above, which starts at 1.0 for a fresh character. Enemies
	# were dying too fast and hitting too soft; more HP means fights
	# actually take some doing, and more damage means getting hit
	# actually costs something.
	const BASE_HEALTH_MULT := 1.6
	# Eased down slightly from 1.3 - between this and the 3-shot burst
	# added at the same time, enemies were landing noticeably more total
	# damage than intended. HP and the burst itself are untouched.
	const BASE_DAMAGE_MULT := 1.1
	max_health = int(max_health * scale_factor * BASE_HEALTH_MULT)
	attack_damage = int(round(attack_damage * scale_factor * BASE_DAMAGE_MULT))
	if is_real_player:
		_apply_real_player_look()
		# Real Players are meant to feel like an actual opposing operator,
		# not another Raider - tougher (was 1.4x, now doubled to 2.8x),
		# hits harder, shoots faster, and can dash to close/break distance.
		max_health = int(max_health * 2.8)
		speed *= 1.05
		attack_damage = int(round(attack_damage * 1.35))
		shoot_cooldown *= 0.7
		_dash_timer = randf_range(4.0, 7.0)
		add_to_group("real_player")
		if gear.is_empty():
			gear = GameManager.generate_random_enemy_gear()
		_apply_gear_visuals()
		_maybe_spawn_cosmetic_pet()
	elif is_elite_guard:
		_apply_random_raider_look()
		# Tougher than a normal Raider so it's a real "should I risk this"
		# decision, but not as extreme as a Real Player - it's meant to be
		# beatable with a decent loadout, not a wall.
		max_health = int(max_health * 1.9)
		attack_damage = int(round(attack_damage * 1.25))
	elif not is_boss:
		_apply_random_raider_look()
	health = max_health
	health_bar.visible = false
	if not is_real_player and not is_boss:
		name_tag.visible = true
		# Deferred on purpose: every typed subclass (NoxiousBat, ToxicWaste,
		# Marauder, Sentinel, RiftWraith, Skeleton, Ghoul, Ghost) calls
		# add_to_group(its own type) AFTER this super._ready() call returns -
		# reading get_display_name() right here, synchronously, would run
		# BEFORE that group tag exists, so every single one of them fell
		# through to the generic "RAIDER" default. Deferring this one frame
		# lets the subclass's add_to_group() finish first.
		call_deferred("_refresh_name_tag")
		name_tag.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78, 1))
	call_deferred("_find_player")

# The label shown above regular (non-boss, non-real-player) enemies -
# their type name, so you know what you're looking at before it's even
# in range to be dangerous.
func _refresh_name_tag() -> void:
	if is_instance_valid(name_tag):
		name_tag.text = get_display_name()

func get_display_name() -> String:
	if is_in_group("skeleton"):
		return "SKELETON"
	if is_in_group("ghost"):
		return "GHOST"
	if is_in_group("ghoul"):
		return "GHOUL"
	if is_in_group("wisp"):
		return "WISP"
	if is_in_group("bat"):
		return "NOXIOUS BAT"
	if is_in_group("toxic_waste"):
		return "GOBLIN"
	if is_in_group("marauder"):
		return "MARAUDER"
	if is_in_group("sentinel"):
		return "SENTINEL"
	if is_in_group("rift_wraith"):
		return "RIFT WRAITH"
	return "RAIDER"

# Regular raiders get a randomized gear palette (and sometimes a cap
# instead of a mask) so a crowd of them doesn't look like the same guy
# copy-pasted - purely cosmetic, no stat changes.
const RAIDER_PALETTES := [
	[Color(0.42, 0.14, 0.1, 1), Color(0.55, 0.18, 0.06, 1)],
	[Color(0.14, 0.16, 0.4, 1), Color(0.08, 0.09, 0.22, 1)],
	[Color(0.32, 0.3, 0.1, 1), Color(0.2, 0.19, 0.05, 1)],
	[Color(0.18, 0.18, 0.19, 1), Color(0.32, 0.32, 0.33, 1)],
	[Color(0.28, 0.06, 0.32, 1), Color(0.16, 0.03, 0.2, 1)],
	[Color(0.1, 0.32, 0.28, 1), Color(0.06, 0.2, 0.17, 1)],
]

func _apply_random_raider_look() -> void:
	var pick: Array = RAIDER_PALETTES[randi() % RAIDER_PALETTES.size()]
	torso.color = pick[0]
	chest_strap.color = pick[1]
	if _using_external_sprite:
		return
	if randf() < 0.35:
		cap.visible = true
		mask.visible = false

const USERNAME_PREFIXES := [
	"Shadow", "Ghost", "Raven", "Viper", "Reaper", "Rogue", "Silent", "Iron",
	"Night", "Rusty", "Grim", "Cold", "Wolf", "Blaze", "Dusty", "Steel",
]
const USERNAME_SUFFIXES := [
	"Hunter", "99", "Actual", "One", "Six", "Wolf", "Fang", "X", "Zero", "13",
	"Prime", "Runner", "Vex", "77", "Reaper", "Ash",
]

func _random_username() -> String:
	var prefix: String = USERNAME_PREFIXES[randi() % USERNAME_PREFIXES.size()]
	var suffix: String = USERNAME_SUFFIXES[randi() % USERNAME_SUFFIXES.size()]
	return "%s%s" % [prefix, suffix]

# --- "Real Player" variant look: tactical green vest + cap instead of the
# raider's red strap + mask, so it reads as visually distinct at a glance,
# plus a small nametag. Only touches the vector shapes when there's no
# external sprite active for this enemy_type_id - real art always wins,
# same rule the sprite loader itself follows below. ---
func _apply_real_player_look() -> void:
	if not _using_external_sprite:
		torso.color = Color(0.14, 0.3, 0.17, 1)
		chest_strap.color = Color(0.07, 0.17, 0.09, 1)
		mask.visible = false
		cap.visible = true
	name_tag.visible = true
	name_tag.text = _random_username()

# Same rarity-tint curve Player.gd's _gear_tint() uses (no skin-color
# check - skins are a player-only cosmetic purchase), so a Real Player
# opponent visibly wearing a Legendary/Mythic piece reads the same way
# your own character's gear does.
func _gear_tint(item) -> Color:
	if item == null:
		return Color.WHITE
	var rarity: String = String(item.get("rarity", "common"))
	var mult: float = GameManager.get_rarity_multiplier(rarity)
	var blend: float = clamp((mult - 1.0) / 9.0, 0.0, 1.0) * 0.6
	return Color.WHITE.lerp(GameManager.get_rarity_color(rarity), blend)

# --- Renders this Real Player's rolled `gear` loadout: an icon per slot
# (same ItemIcon.gd art the inventory grid and Player.gd's own doll use)
# plus a body-armor tint and a weapon scale/sprite swap, mirroring
# Player.gd's _update_appearance()/_update_external_gun_sprite() convention
# so an opponent's loadout actually shows up on them instead of every
# Real Player looking like the same fixed green-vest operator regardless
# of what they're "carrying".
const GUN_SCALE_BY_ICON := {
	"rifle": Vector2(1.35, 1.0), "sniper": Vector2(1.65, 1.0),
	"flamethrower": Vector2(1.5, 1.2), "thorn": Vector2(1.2, 1.0),
	"railgun": Vector2(1.7, 1.15), "alpha_cannon": Vector2(1.9, 1.3),
}
var _enemy_gun_sprite_cache: Dictionary = {}

func _apply_gear_visuals() -> void:
	# Every current is_real_player scene has these (see the get_node_or_
	# null() comment above) but nothing enforces that for scenes added
	# later, so bail instead of null-crashing if one doesn't.
	if helmet_icon == null or backpack_icon == null or accessory_icon == null or boots_icon == null or external_gun_sprite == null:
		return
	var head_item = gear.get("head")
	helmet_icon.visible = head_item != null
	if helmet_icon.visible:
		helmet_icon.icon_key = String(head_item.get("icon_key", "helmet"))
		helmet_icon.icon_color = _gear_tint(head_item)
		helmet_icon.queue_redraw()

	var body_item = gear.get("body")
	var body_tint: Color = _gear_tint(body_item)
	if _using_external_sprite:
		external_sprite.modulate = body_tint
	else:
		torso.modulate = body_tint

	var boots_item = gear.get("boots")
	boots_icon.visible = boots_item != null
	if boots_icon.visible:
		boots_icon.icon_key = String(boots_item.get("icon_key", "boots"))
		boots_icon.icon_color = _gear_tint(boots_item)
		boots_icon.queue_redraw()

	var backpack_item = gear.get("backpack")
	backpack_icon.visible = backpack_item != null
	if backpack_icon.visible:
		backpack_icon.icon_key = String(backpack_item.get("icon_key", "backpack"))
		backpack_icon.icon_color = _gear_tint(backpack_item)
		backpack_icon.queue_redraw()

	var accessory_item = gear.get("accessory")
	accessory_icon.visible = accessory_item != null
	if accessory_item != null:
		accessory_icon.icon_key = String(accessory_item.get("icon_key", "ring"))
		accessory_icon.icon_color = _gear_tint(accessory_item)
		accessory_icon.queue_redraw()

	var weapon_item = gear.get("weapon")
	var weapon_icon: String = String(weapon_item.get("icon_key", "pistol")) if weapon_item != null else "pistol"
	gun_visual.scale = GUN_SCALE_BY_ICON.get(weapon_icon, Vector2(1.0, 1.0))
	gun_visual.modulate = _gear_tint(weapon_item)
	var path := "res://assets/weapons/%s.png" % weapon_icon
	if ResourceLoader.exists(path):
		if not _enemy_gun_sprite_cache.has(weapon_icon):
			_enemy_gun_sprite_cache[weapon_icon] = load(path)
		external_gun_sprite.texture = _enemy_gun_sprite_cache[weapon_icon]
		external_gun_sprite.modulate = gun_visual.modulate
		external_gun_sprite.visible = true
		gun_visual.visible = false
	else:
		external_gun_sprite.visible = false
		gun_visual.visible = true

# A cosmetic-only companion so Real Player opponents occasionally show
# up with a pet trailing them, same as a geared-up human player might.
# Deliberately does NOT reuse Pet.tscn's own script behavior beyond
# _ready() - Pet.gd's _physics_process() makes it follow whichever node
# is in the "player" group and actually deals damage to nearby "enemy"-
# group nodes, both very wrong for something hanging off an enemy, so
# physics_process is disabled immediately and it's parented directly to
# this enemy instead, which makes it follow for free via normal transform
# inheritance and get freed automatically when this enemy does.
const PET_SCENE := preload("res://scenes/Pet.tscn")
const COSMETIC_PET_CHANCE := 0.3

func _maybe_spawn_cosmetic_pet() -> void:
	if randf() >= COSMETIC_PET_CHANCE:
		return
	var pet_ids: Array = GameManager.PET_CATALOG.keys()
	if pet_ids.is_empty():
		return
	var pet = PET_SCENE.instantiate()
	pet.pet_id = pet_ids[randi() % pet_ids.size()]
	add_child(pet)
	pet.position = Vector2(-34, 22)
	pet.set_physics_process(false)

# --- Optional external art: checks res://assets/enemy_<type>.png first
# (set via enemy_type_id, e.g. "skeleton", "ghost") so different enemy
# types can each have their own real art, falling back to the generic
# res://assets/enemy.png, and finally to the built-in vector body if
# neither exists.
func _try_load_external_sprite() -> void:
	if not use_external_sprite:
		return
	var path := "res://assets/enemy.png"
	# Real Players (Arena opponents) have their own dedicated art -
	# enemy_type_id is never set for them (they're not a typed monster),
	# so without this they silently fell through to the generic raider
	# sprite instead of the real_player-specific one that already ships.
	if is_real_player and ResourceLoader.exists("res://assets/enemy_real_player.png"):
		path = "res://assets/enemy_real_player.png"
	elif enemy_type_id != "":
		var typed_path := "res://assets/enemy_%s.png" % enemy_type_id
		if ResourceLoader.exists(typed_path):
			path = typed_path
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if tex == null:
		return
	external_sprite.texture = tex
	external_sprite.visible = true
	_using_external_sprite = true
	for n in ["LeftLeg", "RightLeg", "Torso", "ChestStrap", "Head", "Mask", "Cap", "TorsoOutline", "HeadOutline"]:
		var node = get_node_or_null("Visuals/" + n)
		if node:
			node.visible = false
	for n in ["Barrel", "BarrelOutline", "Sight", "TriggerGuard", "Grip", "SupportHand", "GripHand"]:
		var gun_node = get_node_or_null("Visuals/GunPivot/GunVisual/" + n)
		if gun_node:
			gun_node.visible = false

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Player

func _player_in_smoke() -> bool:
	if player == null:
		return false
	for smoke in get_tree().get_nodes_in_group("smoke_zone"):
		if smoke.has_method("is_point_inside") and smoke.is_point_inside(player.global_position):
			return true
	return false

# A wall between the enemy and its target blocks BOTH detection and
# shooting - previously enemies would chase/shoot through walls just
# because the target was within range, even with no actual sightline.
func _has_line_of_sight_to(target: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	# Raycast from the muzzle, not the body center - the body center can
	# have a clear line to the target while the muzzle (which swings
	# around as the gun rotates to aim) doesn't, which was letting
	# enemies "confirm" a shot and then immediately clip a wall/fence
	# with the actual bullet. Falls back to body center if the muzzle
	# isn't ready yet.
	var origin: Vector2 = muzzle.global_position if is_instance_valid(muzzle) else global_position
	var query := PhysicsRayQueryParameters2D.create(origin, target.global_position)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider = result.get("collider")
	return collider == target or (collider != null and (collider.is_in_group("player") or collider.is_in_group("arena_ally")))

# In Arena matches, opponents shouldn't hard-fixate on the human player
# alone while allies fight independently - picks whichever of {player,
# every arena_ally} is currently nearest, so a 2v2/squad fight actually
# spreads fire across the team instead of every opponent dogpiling one
# person. Outside Arena, group "arena_ally" is always empty, so this
# reduces to exactly the old player-only behavior.
func _current_chase_target() -> Node2D:
	var best: Node2D = player
	var best_dist: float = global_position.distance_to(player.global_position) if player != null else INF
	for a in get_tree().get_nodes_in_group("arena_ally"):
		if not is_instance_valid(a):
			continue
		var d: float = global_position.distance_to(a.global_position)
		if d < best_dist:
			best_dist = d
			best = a
	return best

var stunned_until_ms: int = 0

func apply_stun(duration: float) -> void:
	stunned_until_ms = Time.get_ticks_msec() + int(duration * 1000.0)

var poison_ticks_remaining: int = 0
var poison_damage_per_tick: int = 0
var poison_tick_timer: float = 0.0

func apply_poison(damage_per_tick: int, duration: float) -> void:
	poison_damage_per_tick = damage_per_tick
	poison_ticks_remaining = max(poison_ticks_remaining, int(duration))
	if poison_tick_timer <= 0.0:
		poison_tick_timer = 1.0

# How close is "close enough" before an enemy stops advancing and just
# holds position to shoot - most enemies want a healthy buffer here so
# they don't walk right up into melee range while still shooting.
# Bosses built around an up-close mechanic (Spike's spinning ring)
# override this to keep pressing forward instead of hanging back at a
# comfortable shooting distance that never lets their own mechanic
# actually matter.
func _hold_distance() -> float:
	return attack_range * 0.6

func _physics_process(delta: float) -> void:
	if poison_ticks_remaining > 0:
		poison_tick_timer -= delta
		if poison_tick_timer <= 0.0:
			poison_tick_timer = 1.0
			poison_ticks_remaining -= 1
			take_damage(poison_damage_per_tick)
	if player == null or not is_instance_valid(player):
		return
	if Time.get_ticks_msec() < stunned_until_ms:
		velocity = velocity.lerp(Vector2.ZERO, clamp(delta * _ice_control_rate(), 0.0, 1.0))
		move_and_slide()
		_animate(delta)
		return

	if is_real_player:
		_dash_timer -= delta
		if _dash_active_time > 0.0:
			_dash_active_time -= delta
		elif _dash_timer <= 0.0:
			_dash_active_time = DASH_DURATION
			_dash_timer = randf_range(4.0, 7.0)
			_spawn_dash_particles()

	# Real fog of war: only visible if inside the player's flashlight cone
	# (or point-blank range). The AI still runs in the dark - you just
	# can't see it happening.
	visible = player.can_see_point(global_position)

	# Enemies see less clearly through cover - a player hiding in a bush
	# or standing in smoke is much harder to spot, UNLESS they've just
	# fired their gun. A gunshot is loud enough to give away exactly
	# where you are regardless of cover - the bush only hides someone
	# sitting still and quiet, not someone actively shooting from it.
	var chase_target: Node2D = _current_chase_target()
	var dist := global_position.distance_to(chase_target.global_position)

	# effective_range is always <= detection_range below (stealth only ever
	# shrinks it), so an enemy already further than that can never detect
	# the target regardless of stealth - skip the smoke-zone group scan
	# entirely once that's true instead of running it on every enemy every
	# physics tick no matter the distance.
	var can_detect: bool = false
	if dist <= max(detection_range, 60.0):
		var effective_range := detection_range - GameManager.get_upgrade_bonus("stealth")
		if GameManager.player_trait == "ghost_step":
			effective_range *= 0.8
		# Bush/smoke stealth only ever applies to the actual human player -
		# arena allies have no stealth mechanic, so they're always "loud".
		var is_hidden: bool = chase_target == player and (player.in_bush or _player_in_smoke()) and not player.is_making_noise()
		if is_hidden:
			effective_range = detection_range * 0.25 - GameManager.get_upgrade_bonus("stealth")
		effective_range = max(effective_range, 60.0)
		can_detect = dist <= effective_range and _has_line_of_sight_to(chase_target)
	if can_detect:
		gun_pivot.look_at(chase_target.global_position)
		_turn_body_toward(chase_target.global_position, delta)
		var target_velocity := Vector2.ZERO
		if dist > _hold_distance():
			target_velocity = (chase_target.global_position - global_position).normalized() * speed
		var lerp_rate := _ice_control_rate()
		if is_real_player and _dash_active_time > 0.0:
			target_velocity = (chase_target.global_position - global_position).normalized() * speed * DASH_SPEED_MULT
			lerp_rate = 25.0
		velocity = velocity.lerp(target_velocity, clamp(delta * lerp_rate, 0.0, 1.0))
		move_and_slide()
		if dist <= attack_range and can_shoot:
			_shoot()
	else:
		velocity = velocity.lerp(Vector2.ZERO, clamp(delta * _ice_control_rate(), 0.0, 1.0))
		move_and_slide()

	_animate(delta)

# Turns the whole body (and any external sprite) smoothly to face the
# player - previously only gun_pivot rotated, so the body/head just sat
# there in its default facing while the gun spun freely around it. That's
# why it looked like enemies weren't looking at you, and why the muzzle
# (fixed to the gun, not the body) could end up passing right through
# the shoulder/head art on its way to wherever it needed to point.
# Matches Player.gd's _handle_body_turn: the gun still snaps instantly
# for accurate aim, only the body eases into the turn.
const BODY_TURN_SPEED := 9.0
const NAME_TAG_OFFSET := Vector2(-50, -60)

func _turn_body_toward(target_global_pos: Vector2, delta: float) -> void:
	var to_target: Vector2 = target_global_pos - global_position
	if to_target.length_squared() < 1.0:
		return
	var target_angle: float = to_target.angle()
	visuals.rotation = lerp_angle(visuals.rotation, target_angle, clamp(delta * BODY_TURN_SPEED, 0.0, 1.0))

func _animate(delta: float) -> void:
	var move_amount: float = clamp(velocity.length() / max(speed, 1.0), 0.0, 1.0)
	if move_amount > 0.05:
		walk_cycle += delta * 11.0
	var amp := move_amount * 3.0

	left_leg.position = Vector2(-5, 16 + sin(walk_cycle) * amp)
	right_leg.position = Vector2(5, 16 + sin(walk_cycle + PI) * amp)

	var bob := sin(walk_cycle * 2.0) * amp * 0.25
	visuals.position = Vector2(0, bob)

	recoil = lerp(recoil, 0.0, delta * 14.0)
	gun_visual.position = Vector2(recoil, 0)

	# NameTag lives under Visuals so it inherits the body's rotation and
	# walk-cycle bob, which is exactly why it was swinging/drifting around
	# instead of sitting still above the character's head. Canceling out
	# Visuals' current rotation AND position here means the nametag's
	# effective position is always the constant NAME_TAG_OFFSET, no matter
	# how the body is turned or bobbing.
	name_tag.rotation = -visuals.rotation
	name_tag.position = (NAME_TAG_OFFSET - visuals.position).rotated(-visuals.rotation)

func _shoot() -> void:
	can_shoot = false
	# Same fix as Player.gd - direction comes from the gun's actual aim
	# rotation (already correctly aimed via look_at() before this runs),
	# not a fresh muzzle-to-target vector that can point backwards if
	# the target is closer than the muzzle's forward offset.
	var base_dir: Vector2 = Vector2.RIGHT.rotated(gun_pivot.global_rotation)
	var base_angle: float = base_dir.angle()
	# 3 shots in a tight spread instead of one - makes every enemy
	# encounter meaningfully more dangerous without needing a whole new
	# weapon system, and reads as "burst fire" rather than a single
	# perfect shot every time.
	const ENEMY_BURST_COUNT := 3
	const ENEMY_BURST_SPREAD_RADIANS := 0.16
	for i in range(ENEMY_BURST_COUNT):
		var t: float = (float(i) / float(ENEMY_BURST_COUNT - 1)) - 0.5 if ENEMY_BURST_COUNT > 1 else 0.0
		var shot_angle: float = base_angle + t * ENEMY_BURST_SPREAD_RADIANS
		var shot_dir := Vector2(cos(shot_angle), sin(shot_angle))
		var bullet = BULLET_SCENE.instantiate()
		bullet.direction = shot_dir
		bullet.is_enemy_bullet = true
		bullet.damage = attack_damage
		bullet.is_operator_bullet = is_real_player
		bullet.source_name = get_display_name()
		bullet.source_weapon = "Gunfire"
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = muzzle.global_position
	recoil = -5.0
	_flash_muzzle()
	Sfx.play_gunshot()
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

# A quick electric-blue streak/poof at the moment a Real Player dashes -
# purely visual feedback so the sudden burst of speed reads as an
# intentional move instead of a stutter.
func _spawn_dash_particles() -> void:
	var burst := Node2D.new()
	get_tree().current_scene.add_child(burst)
	burst.global_position = global_position
	burst.z_index = 7
	for i in range(8):
		var chip := Polygon2D.new()
		var s := randf_range(1.5, 3.5)
		chip.polygon = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
		chip.color = Color(0.35, 0.85, 1.0, 0.9)
		burst.add_child(chip)
		var ang := randf_range(0.0, TAU)
		var dist := randf_range(14, 36)
		var target := Vector2(cos(ang), sin(ang)) * dist
		var tw := chip.create_tween()
		tw.set_parallel(true)
		tw.tween_property(chip, "position", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(chip, "modulate:a", 0.0, 0.32)
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(burst):
			burst.queue_free()
	)

func _flash_muzzle() -> void:
	muzzle_flash.visible = true
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false

const HIT_LINES := [
	"Argh!", "Taking fire!", "Contact!", "I'm hit!", "Ah-!",
	"Watch it!", "Damn it!", "Where's that coming from?!",
]
var _took_first_hit: bool = false

func take_damage(amount: int) -> void:
	if is_dead:
		return
	health -= amount
	if health <= 0:
		die()
		return
	# Real Player operators only, and only a single 50/50 roll on the
	# very first hit they take this fight - not a recheck on every hit.
	if is_real_player and not _took_first_hit:
		_took_first_hit = true
		if randf() < 0.5:
			_show_hit_bubble()

# Reuses the same lightweight floating-Label-that-fades pattern pets
# already use for their own chat bubbles - no new scene needed.
func _show_hit_bubble() -> void:
	var bubble := Label.new()
	bubble.text = HIT_LINES[randi() % HIT_LINES.size()]
	bubble.add_theme_font_size_override("font_size", 12)
	bubble.add_theme_color_override("font_color", Color(1, 0.9, 0.9, 1))
	bubble.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	bubble.add_theme_constant_override("outline_size", 3)
	bubble.position = Vector2(-30, -92)
	add_child(bubble)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.35)
	tw.tween_callback(bubble.queue_free)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	GameManager.notify_event("kill_enemy")
	GameManager.record_kill()
	if is_real_player:
		GameManager.grant_stones(GameManager.REAL_PLAYER_KILL_STONES)
	_mark_discovered()
	if player != null and is_instance_valid(player) and player.in_bush:
		GameManager.notify_event("sneak_kill")
	if is_boss:
		GameManager.notify_event("kill_spike")
	if is_in_group("ghost"):
		GameManager.notify_event("kill_a_ghost")
	var death_pos := global_position
	var effective_loot_chance: float = clamp(loot_drop_chance + GameManager.get_equipped_bonus("loot_sense") + GameManager.get_upgrade_bonus("loot_sense") + (0.08 if GameManager.player_trait == "loot_hound" else 0.0), 0.0, 1.0)
	var loot_data: Dictionary = GameManager.roll_corpse_loot(is_real_player, drop_key_id, drop_key_label, effective_loot_chance, is_boss or is_elite_guard)
	call_deferred("_spawn_corpse", death_pos, loot_data)
	call_deferred("_spawn_kill_burst", death_pos)
	queue_free()

func _mark_discovered() -> void:
	if is_in_group("spike"):
		GameManager.mark_enemy_discovered("spike")
	elif is_in_group("rattles"):
		GameManager.mark_enemy_discovered("rattles")
	elif is_in_group("skeleton"):
		GameManager.mark_enemy_discovered("skeleton")
	elif is_in_group("ghost"):
		GameManager.mark_enemy_discovered("ghost")
	elif is_in_group("ghoul"):
		GameManager.mark_enemy_discovered("ghoul")
	elif is_in_group("wisp"):
		GameManager.mark_enemy_discovered("wisp")
	elif is_in_group("bat"):
		GameManager.mark_enemy_discovered("noxious_bat")
	elif is_in_group("toxic_waste"):
		GameManager.mark_enemy_discovered("toxic_waste")
	elif is_in_group("marauder"):
		GameManager.mark_enemy_discovered("marauder")
	elif is_in_group("sentinel"):
		GameManager.mark_enemy_discovered("sentinel")
	elif is_in_group("rift_wraith"):
		GameManager.mark_enemy_discovered("rift_wraith")
	elif is_real_player:
		GameManager.mark_enemy_discovered("real_player")
	else:
		GameManager.mark_enemy_discovered("raider")

func _spawn_corpse(pos: Vector2, loot_data: Dictionary) -> void:
	var corpse = CORPSE_SCENE.instantiate()
	corpse.loot_items = loot_data.get("items", [])
	corpse.currency_drops = loot_data.get("currency", {})
	corpse.is_real_player = is_real_player
	get_tree().current_scene.add_child(corpse)
	corpse.global_position = pos

# A quick vector particle burst so kills feel punchy - on top of the blood
# splatter the bullet itself already spawns on hit.
func _spawn_kill_burst(pos: Vector2) -> void:
	var burst := Node2D.new()
	get_tree().current_scene.add_child(burst)
	burst.global_position = pos
	burst.z_index = 8
	var colors := [Color(0.8, 0.15, 0.1, 1), Color(0.95, 0.75, 0.2, 1), Color(0.9, 0.9, 0.88, 1)]
	for i in range(12):
		var chip := Polygon2D.new()
		var s := randf_range(2.0, 4.5)
		chip.polygon = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
		chip.color = colors[randi() % colors.size()]
		burst.add_child(chip)
		var ang := randf_range(0.0, TAU)
		var dist := randf_range(26, 64)
		var target := Vector2(cos(ang), sin(ang)) * dist
		var tw := chip.create_tween()
		tw.set_parallel(true)
		tw.tween_property(chip, "position", target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(chip, "modulate:a", 0.0, 0.5)
		tw.tween_property(chip, "rotation", randf_range(-3.0, 3.0), 0.45)
	get_tree().create_timer(0.65).timeout.connect(func():
		if is_instance_valid(burst):
			burst.queue_free()
	)
