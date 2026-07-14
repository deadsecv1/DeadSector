extends Node2D

const RECRUIT_SCENE := preload("res://scenes/Recruit.tscn")
const RaidPartyMemberScript := preload("res://scripts/RaidPartyMember.gd")
const PET_SCENE := preload("res://scenes/Pet.tscn")

@onready var player = $Player
@onready var hud = $HUD
@onready var world_darkness: CanvasModulate = $WorldDarkness

const RUN_TIME_LIMIT := 600.0
var time_remaining: float = RUN_TIME_LIMIT

func _ready() -> void:
	GameManager.set_crosshair_cursor()
	GameManager.in_graveyard_run = true
	_spawn_recruit()
	_spawn_raid_party()
	_spawn_pet()
	player.stats_ready.connect(hud.update_stats)
	player.ammo_changed.connect(hud.update_ammo)
	player._update_ammo_display()
	player.stunned.connect(hud.flash_stun)
	player.health_changed.connect(hud._on_player_health_changed)
	# Always midnight in the Graveyard, fog-dim regardless of the
	# sector's actual day/night cycle - this place doesn't follow the
	# same clock as everywhere else.
	world_darkness.color = Color(0.14, 0.15, 0.17, 1)
	time_remaining = RUN_TIME_LIMIT
	hud.update_time_remaining(time_remaining)
	if GameManager.graveyard_kills < GameManager.GRAVEYARD_KILLS_FOR_LOOM_WEAVER:
		Notify.show_toast("The Loom-weaver stirs at 100 kills. Progress: %d/%d" % [GameManager.graveyard_kills, GameManager.GRAVEYARD_KILLS_FOR_LOOM_WEAVER])

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
