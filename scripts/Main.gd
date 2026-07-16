extends Node2D

const RECRUIT_SCENE := preload("res://scenes/Recruit.tscn")
const RaidPartyMemberScript := preload("res://scripts/RaidPartyMember.gd")
const PET_SCENE := preload("res://scenes/Pet.tscn")
const WANDERING_TRADER_SCENE := preload("res://scenes/WanderingTrader.tscn")
const ELITE_ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const ELITE_CACHE_SCENE := preload("res://scenes/DebrisStash.tscn")

@onready var player = $Player
@onready var hud = $HUD
@onready var world_darkness: CanvasModulate = $WorldDarkness
@onready var power_switch = $AshenHousePowerSwitch
@onready var ashen_lamps: Array[Node2D] = [$AshenHouseLamp1, $AshenHouseLamp2, $AshenHouseLamp3]

const RUN_TIME_LIMIT := 780.0
var time_remaining: float = RUN_TIME_LIMIT

func _ready() -> void:
	GameManager.set_crosshair_cursor()
	_spawn_recruit()
	_spawn_raid_party()
	_spawn_pet()
	_maybe_spawn_wandering_trader()
	_maybe_spawn_elite_cache_event()
	player.stats_ready.connect(hud.update_stats)
	player.ammo_changed.connect(hud.update_ammo)
	# Player's own _ready() already fired one ammo_changed before this
	# scene's _ready() (which runs after all its children, Player
	# included, are already ready) got a chance to connect - without
	# this, the HUD sits on its static placeholder text until the first
	# shot/reload actually changes something.
	player._update_ammo_display()
	player.stunned.connect(hud.flash_stun)
	player.health_changed.connect(hud._on_player_health_changed)
	power_switch.activated.connect(_on_power_activated)
	var darkness: float = GameManager.get_darkness_factor_for_hour(GameManager.selected_raid_hour, GameManager.is_night_raid)
	if GameManager.is_night_raid:
		world_darkness.color = Color(0.2, 0.2, 0.26, 1).lerp(Color(0.045, 0.045, 0.07, 1), darkness)
		Notify.show_toast("Night Raid (%s) - stay sharp out there." % GameManager.format_hour(GameManager.selected_raid_hour))
	else:
		world_darkness.color = Color(0.68, 0.68, 0.72, 1).lerp(Color(0.4, 0.4, 0.44, 1), darkness)
	time_remaining = RUN_TIME_LIMIT
	hud.update_time_remaining(time_remaining)

func _on_power_activated() -> void:
	for lamp: Node2D in ashen_lamps:
		lamp.visible = true
		lamp.modulate.a = 0.0
		var tw: Tween = lamp.create_tween()
		tw.tween_property(lamp, "modulate:a", 1.0, 0.8)

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

func _maybe_spawn_wandering_trader() -> void:
	if randf() >= 0.5:
		return
	var trader = WANDERING_TRADER_SCENE.instantiate()
	add_child(trader)
	# Spawn somewhere away from the player's start so they have to find
	# him, but still well within the walkable map.
	var ang := randf_range(0.0, TAU)
	trader.global_position = player.global_position + Vector2(cos(ang), sin(ang)) * randf_range(800.0, 1400.0)
	trader.trade_requested.connect(func(): hud.open_wandering_trader(trader))

# A rare, telegraphed mid-raid event: a small guarded cache with a real
# chance of dying to reach - 2 tougher Elite Guards (tinted red so
# they're identifiable at a glance, unlike a normal Raider) ringed
# around a genuinely good item. Entirely optional - spawns well away
# from the player's start and nothing forces a detour to find it.
func _maybe_spawn_elite_cache_event() -> void:
	if randf() >= 0.18:
		return
	var ang := randf_range(0.0, TAU)
	var center: Vector2 = player.global_position + Vector2(cos(ang), sin(ang)) * randf_range(1000.0, 1800.0)
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
