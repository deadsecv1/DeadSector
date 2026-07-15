extends Node2D

# The Arena's map - a small, close-quarters battle room with a grid-
# tiled floor. Opponents are "Real Player" Enemy.gd instances (the same
# tougher, human-styled variant already used for the occasional Real
# Player encounter in normal raids), matching the game's honest "this is
# simulated, not live netcode" framing used everywhere else (Global
# Chat, Find a Team, the Leaderboard). Beating every opponent grants
# Arena Rank points and routes to ArenaVictory - losing routes to
# ArenaDefeat, same "no gear loss" framing as any other Arena outcome.
#
# Lilly and the match menu (Current Teams/Return) used to live here via
# an in-map NPC - Lilly's since moved to the Social Place hub
# (SocialPlace.tscn), so the same menu now opens on Escape instead of
# walking up to an NPC that's no longer on this map.

@onready var player = $Player
@onready var hud = $HUD
@onready var lilly_panel: Panel = $ArenaUI/LillyPanel
@onready var current_teams_panel: Panel = $ArenaUI/CurrentTeamsPanel
@onready var countdown_label: Label = $ArenaUI/CountdownLabel

var _opponents_remaining: int = 0
var _match_won: bool = false
var _esc_was_down: bool = false
# Snapshot of current_teams_panel.visible taken at the END of the previous
# frame - ArenaCurrentTeamsPanel.gd closes ITSELF via its own
# _unhandled_input on Escape (being a deeper child, it can consume the
# event before this script's own input ever saw it), so a live check here
# would race the exact same way polling was needed elsewhere in the
# codebase for this same class of bug.
var _current_teams_was_open_at_frame_start: bool = false

func _process(_delta: float) -> void:
	var esc_down := Input.is_key_pressed(KEY_ESCAPE)
	if esc_down and not _esc_was_down:
		# HUD's own Escape handling is Input.is_key_pressed() polling in
		# its own _process(), which reads raw hardware key state and has
		# no way to know Lilly's panel exists at all - without this, it
		# opened its own Pause Menu on the exact same keypress that just
		# opened/closed this one. Escape in this scene is always fully
		# owned by the Lilly/Current-Teams system, never HUD's Pause Menu.
		hud.suppress_escape_this_frame = true
		if _current_teams_was_open_at_frame_start:
			pass
		elif current_teams_panel.visible:
			current_teams_panel.visible = false
		else:
			lilly_panel.visible = not lilly_panel.visible
	_esc_was_down = esc_down
	_current_teams_was_open_at_frame_start = current_teams_panel.visible

func _ready() -> void:
	GameManager.set_crosshair_cursor()
	GameManager.is_arena_match = true
	GameManager.last_arena_kills = 0
	player.stats_ready.connect(hud.update_stats)
	player.ammo_changed.connect(hud.update_ammo)
	player._update_ammo_display()
	player.stunned.connect(hud.flash_stun)
	player.health_changed.connect(hud._on_player_health_changed)
	_spawn_pet()

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

	# Movement/shooting stay locked, and opponents/ally stay unspawned,
	# until the countdown hits GO - matches the "Choose Your Loadout"
	# screen's promise that picking a preset doesn't drop you straight
	# into a fight with no warning.
	player.set_input_locked(true)
	_run_countdown()

const COUNTDOWN_STEPS := ["5", "4", "3", "2", "1", "GO!"]
const COUNTDOWN_STEP_SECONDS := 0.8

func _run_countdown() -> void:
	for step in COUNTDOWN_STEPS:
		countdown_label.text = step
		await get_tree().create_timer(COUNTDOWN_STEP_SECONDS).timeout
	countdown_label.text = ""
	player.set_input_locked(false)
	var team_size: int = int(GameManager.current_arena_match.get("team_size", 1))
	_spawn_opponents(team_size)
	if team_size > 1:
		_spawn_allies(team_size - 1)

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const ALLY_SCRIPT := preload("res://scripts/ArenaAlly.gd")
const PET_SCENE := preload("res://scenes/Pet.tscn")
const OPPONENT_BASE_X := 300.0
const ALLY_BASE_X := -320.0
const ROSTER_SPREAD_Y := 300.0

# Spreads up to `count` spawn points evenly across the room's vertical
# span at a fixed x (positive for the opponent side, negative for the
# ally side) - replaces the old fixed 2-slot position arrays now that
# matches can field rosters up to 7v7 instead of just 1v1/2v2.
func _spread_positions(count: int, base_x: float) -> Array:
	var positions: Array = []
	if count <= 1:
		positions.append(Vector2(base_x, 0))
		return positions
	for i in range(count):
		var t: float = float(i) / float(count - 1)
		positions.append(Vector2(base_x, lerp(-ROSTER_SPREAD_Y, ROSTER_SPREAD_Y, t)))
	return positions

func _spawn_pet() -> void:
	if GameManager.equipped_pet == "":
		return
	var pet = PET_SCENE.instantiate()
	pet.pet_id = GameManager.equipped_pet
	add_child(pet)
	pet.global_position = player.global_position + Vector2(-40, 30)

func _spawn_opponents(team_size: int) -> void:
	_opponents_remaining = team_size
	var spots := _spread_positions(team_size, OPPONENT_BASE_X)
	var roster: Array = GameManager.current_arena_match.get("team2", [])
	for i in range(team_size):
		var opponent = ENEMY_SCENE.instantiate()
		opponent.is_real_player = true
		# Same gear the Current Teams panel already shows for this roster
		# slot, so the opponent you see standing there matches the loadout
		# you scouted before the match started instead of rolling a fresh,
		# unrelated one (Enemy.gd auto-rolls its own if this is empty, e.g.
		# for a 1v1 where team2 has no gear-bearing entries at all).
		if i < roster.size():
			opponent.gear = roster[i].get("gear", {})
		# died (not tree_exited) - tree_exited also fires on ordinary scene
		# teardown (e.g. leaving via "Return to Main Menu" while an
		# opponent is still alive), which used to be able to misfire a win.
		opponent.died.connect(_on_opponent_defeated)
		add_child(opponent)
		opponent.global_position = spots[i]
		opponent.get_node("Visuals").modulate = Color(1.1, 0.75, 0.75, 1)

# The player's teammates (up to 6, for a 7v7) - reuses Enemy.tscn's
# visuals with its script swapped to ArenaAlly.gd (set_script() before
# add_child() so ArenaAlly's own _ready() is what actually fires).
# team_index maps each ally to its slot in current_arena_match["team1"]
# (team1[0] is always the player).
func _spawn_allies(count: int) -> void:
	var spots := _spread_positions(count, ALLY_BASE_X)
	for i in range(count):
		var ally = ENEMY_SCENE.instantiate()
		ally.set_script(ALLY_SCRIPT)
		ally.team_index = i + 1
		add_child(ally)
		ally.global_position = spots[i]

func _on_opponent_defeated() -> void:
	if _match_won or GameManager.run_over:
		return
	GameManager.last_arena_kills += 1
	_opponents_remaining -= 1
	if _opponents_remaining <= 0:
		_win_match()

func _win_match() -> void:
	_match_won = true
	var gained: int = randi_range(60, 140)
	GameManager.last_arena_rank_points_gained = gained
	GameManager.grant_arena_rank_points(gained)
	# Routes through the normal end_run(true) - is_arena_match being true
	# is what makes it land on ArenaVictory.tscn instead of RaidRewards.tscn
	# (see GameManager.end_run). Arena has no real loot, so the raid-side
	# effects of end_run's success branch (carried_value, loot quests,
	# etc.) are all harmless no-ops here.
	GameManager.end_run(true)

func _return_to_main_menu() -> void:
	# Leaving early (before a win/loss fires end_run()) would otherwise
	# leave the player's real gear/pet permanently swapped for whatever
	# Arena Loadout Preset they picked, and is_arena_match stuck true.
	GameManager.end_arena_loadout_if_active()
	GameManager.is_arena_match = false
	GameManager.is_clan_war = false
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")
