extends Node2D

# Arena's social hub - Lilly's nook and her panel (Current Teams/Return),
# relocated here from The Grid so the battle map is combat-only. Also
# hosts 5-8 simulated "real players" that wander, despawn, and respawn
# on a roughly 5-minute cycle each. Players can fire their weapon here
# freely - none of these NPCs ever join the "enemy" group, so nothing
# here can take damage (see SocialPlaceNpc.gd).

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const NPC_SCRIPT := preload("res://scripts/SocialPlaceNpc.gd")
const PET_SCENE := preload("res://scenes/Pet.tscn")

const MIN_NPCS := 5
const MAX_NPCS := 8
# "Roughly every 5 minutes" per-NPC, not a single global timer - each
# one gets its own randomized lifetime in this range so despawns/
# respawns stagger naturally instead of the whole crowd turning over
# in lockstep.
const NPC_LIFETIME_MIN := 240.0
const NPC_LIFETIME_MAX := 360.0
const SPAWN_SPREAD := Vector2(420.0, 320.0)
const RESPAWN_CHECK_INTERVAL := 3.0

@onready var player = $Player
@onready var hud = $HUD
@onready var lilly_station = $LillyStation
@onready var lilly_panel: Panel = $ArenaUI/LillyPanel
@onready var current_teams_panel: Panel = $ArenaUI/CurrentTeamsPanel

var _npc_despawn_at_ms: Dictionary = {}
var _respawn_check_timer: float = 0.0
var _esc_was_down: bool = false
# Snapshot taken at the END of the previous frame, not a live check -
# ArenaCurrentTeamsPanel.gd closes ITSELF via its own _unhandled_input on
# Escape (a deeper child, so it can consume the event before this script
# ever sees it), same class of race fixed elsewhere in the codebase for
# this exact pattern.
var _current_teams_was_open_at_frame_start: bool = false

func _ready() -> void:
	GameManager.set_crosshair_cursor()
	player.stats_ready.connect(hud.update_stats)
	player.ammo_changed.connect(hud.update_ammo)
	player._update_ammo_display()
	player.stunned.connect(hud.flash_stun)
	player.health_changed.connect(hud._on_player_health_changed)
	_spawn_pet()

	for i in range(randi_range(MIN_NPCS, MAX_NPCS)):
		_spawn_npc()

	lilly_station.interacted.connect(_open_lilly_panel)
	lilly_panel.visible = false
	current_teams_panel.visible = false
	var return_btn: Button = lilly_panel.get_node("VBox/ReturnButton")
	var teams_btn: Button = lilly_panel.get_node("VBox/CurrentTeamsButton")
	var close_btn: Button = lilly_panel.get_node("VBox/CloseButton")
	return_btn.pressed.connect(_return_to_main_menu)
	teams_btn.pressed.connect(func():
		lilly_panel.visible = false
		current_teams_panel.visible = true
		current_teams_panel.open()
	)
	close_btn.pressed.connect(func(): lilly_panel.visible = false)
	current_teams_panel.closed.connect(func():
		current_teams_panel.visible = false
		lilly_panel.visible = true
	)

func _spawn_pet() -> void:
	if GameManager.equipped_pet == "":
		return
	var pet = PET_SCENE.instantiate()
	pet.pet_id = GameManager.equipped_pet
	add_child(pet)
	pet.global_position = player.global_position + Vector2(-40, 30)

func _spawn_npc() -> void:
	var npc = ENEMY_SCENE.instantiate()
	npc.set_script(NPC_SCRIPT)
	add_child(npc)
	npc.global_position = Vector2(
		randf_range(-SPAWN_SPREAD.x, SPAWN_SPREAD.x),
		randf_range(-SPAWN_SPREAD.y, SPAWN_SPREAD.y),
	)
	var lifetime: float = randf_range(NPC_LIFETIME_MIN, NPC_LIFETIME_MAX)
	_npc_despawn_at_ms[npc] = Time.get_ticks_msec() + int(lifetime * 1000.0)

func _process(delta: float) -> void:
	var esc_down := Input.is_key_pressed(KEY_ESCAPE)
	if esc_down and not _esc_was_down:
		if _current_teams_was_open_at_frame_start:
			# ArenaCurrentTeamsPanel already closed itself (and its closed
			# signal already restored lilly_panel) via its own
			# _unhandled_input on this same press - just make sure HUD's
			# poll-based Pause Menu doesn't also open on top of that.
			hud.suppress_escape_this_frame = true
		elif current_teams_panel.visible:
			current_teams_panel.visible = false
			lilly_panel.visible = true
			hud.suppress_escape_this_frame = true
		elif lilly_panel.visible:
			lilly_panel.visible = false
			hud.suppress_escape_this_frame = true
	_esc_was_down = esc_down
	_current_teams_was_open_at_frame_start = current_teams_panel.visible

	var now := Time.get_ticks_msec()
	var to_forget: Array = []
	for npc in _npc_despawn_at_ms.keys():
		if not is_instance_valid(npc):
			to_forget.append(npc)
			continue
		if now >= int(_npc_despawn_at_ms[npc]):
			npc.queue_free()
			to_forget.append(npc)
	for npc in to_forget:
		_npc_despawn_at_ms.erase(npc)

	_respawn_check_timer += delta
	if _respawn_check_timer >= RESPAWN_CHECK_INTERVAL:
		_respawn_check_timer = 0.0
		if _npc_despawn_at_ms.size() < MIN_NPCS:
			_spawn_npc()

func _open_lilly_panel() -> void:
	lilly_panel.visible = true

func _return_to_main_menu() -> void:
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")
