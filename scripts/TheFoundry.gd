extends Node2D

const RECRUIT_SCENE := preload("res://scenes/Recruit.tscn")
const RaidPartyMemberScript := preload("res://scripts/RaidPartyMember.gd")
const PET_SCENE := preload("res://scenes/Pet.tscn")
const ELITE_ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const ELITE_CACHE_SCENE := preload("res://scenes/DebrisStash.tscn")

@onready var player = $Player
@onready var hud = $HUD
@onready var world_darkness: CanvasModulate = $WorldDarkness

const RUN_TIME_LIMIT := 600.0
var time_remaining: float = RUN_TIME_LIMIT

func _ready() -> void:
	GameManager.set_crosshair_cursor()
	_spawn_recruit()
	_spawn_raid_party()
	_spawn_pet()
	_maybe_spawn_elite_cache_event()
	player.stats_ready.connect(hud.update_stats)
	player.ammo_changed.connect(hud.update_ammo)
	player._update_ammo_display()
	player.stunned.connect(hud.flash_stun)
	player.health_changed.connect(hud._on_player_health_changed)
	var darkness: float = GameManager.get_darkness_factor_for_hour(GameManager.selected_raid_hour, GameManager.is_night_raid)
	if GameManager.is_night_raid:
		world_darkness.color = Color(0.18, 0.15, 0.14, 1).lerp(Color(0.04, 0.03, 0.03, 1), darkness)
		Notify.show_toast("Night Raid (%s) - the Foundry's corridors are pitch dark." % GameManager.format_hour(GameManager.selected_raid_hour))
	else:
		world_darkness.color = Color(0.62, 0.56, 0.5, 1).lerp(Color(0.38, 0.34, 0.3, 1), darkness)
	time_remaining = RUN_TIME_LIMIT
	hud.update_time_remaining(time_remaining)

func _process(delta: float) -> void:
	if GameManager.run_over:
		return
	time_remaining = max(0.0, time_remaining - delta)
	hud.update_time_remaining(time_remaining)
	if time_remaining <= 0.0:
		GameManager.timeout_run()

func _spawn_recruit() -> void:
	if GameManager.selected_recruit == "":
		return
	var recruit = RECRUIT_SCENE.instantiate()
	recruit.recruit_id = GameManager.selected_recruit
	add_child(recruit)
	recruit.global_position = player.global_position + Vector2(-70, 0)

# A party joined via a Recruit-channel chat invite (see GlobalChatBox.gd)
# - GameManager.pending_raid_party is a one-shot handoff, consumed and
# cleared here so a later raid entered normally doesn't also spawn a
# leftover party. Spread around the player instead of stacked on one
# spot, same idea as TheGrid.gd's _spread_positions() for Arena allies.
func _spawn_raid_party() -> void:
	if GameManager.pending_raid_party.is_empty():
		return
	var party: Array = GameManager.pending_raid_party.duplicate()
	GameManager.pending_raid_party = []
	for i in range(party.size()):
		var member = RECRUIT_SCENE.instantiate()
		member.set_script(RaidPartyMemberScript)
		member.party_entry = party[i]
		var ang: float = (float(i) / float(max(1, party.size()))) * TAU
		member.follow_offset = Vector2(cos(ang), sin(ang)) * 80.0
		add_child(member)
		member.global_position = player.global_position + member.follow_offset

func _spawn_pet() -> void:
	if GameManager.equipped_pet == "":
		return
	var pet = PET_SCENE.instantiate()
	pet.pet_id = GameManager.equipped_pet
	add_child(pet)
	pet.global_position = player.global_position + Vector2(-40, 30)

# A rare, telegraphed mid-raid event: a small guarded cache with a real
# chance of dying to reach - 2 tougher Elite Guards (tinted red so
# they're identifiable at a glance, unlike a normal Raider) ringed
# around a genuinely good item. Entirely optional - spawns well away
# from the player's start and nothing forces a detour to find it.
#
# Unlike the other raid maps, the Foundry's walkable area is a cross
# shape, not an open rectangle - a free-form random angle/distance could
# land the cache in one of the 4 solid corners between arms. Picks a
# random arm and a distance along ITS length instead, so it always
# lands somewhere genuinely walkable.
func _maybe_spawn_elite_cache_event() -> void:
	if randf() >= 0.18:
		return
	var arm_dir: Vector2 = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT][randi() % 4]
	var center: Vector2 = arm_dir * randf_range(600.0, 950.0)
	for i in range(2):
		var guard = ELITE_ENEMY_SCENE.instantiate()
		guard.is_elite_guard = true
		add_child(guard)
		guard.global_position = center + Vector2(60.0, 0.0).rotated(TAU * i / 2.0)
		guard.modulate = Color(1.3, 0.55, 0.5, 1)
	var cache = ELITE_CACHE_SCENE.instantiate()
	cache.item_name = "Guarded Cache"
	cache.base_value = 320
	cache.rarity = ["epic", "legendary"][randi() % 2]
	add_child(cache)
	cache.global_position = center
