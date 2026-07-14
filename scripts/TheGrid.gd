extends Node2D

# The Arena's map - a small, close-quarters 1v1/2v2 room with a grid-
# tiled floor. Opponents are "Real Player" Enemy.gd instances (the same
# tougher, human-styled variant already used for the occasional Real
# Player encounter in normal raids), matching the game's honest "this is
# simulated, not live netcode" framing used everywhere else (Global
# Chat, Find a Team, the Leaderboard). Beating every opponent grants
# Arena Rank points and returns you to the Main Menu - losing routes
# through the normal Death Screen, same as any other map.

@onready var player = $Player
@onready var hud = $HUD
@onready var lilly_station = $LillyStation
@onready var lilly_panel: Panel = $ArenaUI/LillyPanel
@onready var current_teams_panel: Panel = $ArenaUI/CurrentTeamsPanel
@onready var countdown_label: Label = $ArenaUI/CountdownLabel

var _opponents_remaining: int = 0
var _match_won: bool = false

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
	current_teams_panel.closed.connect(func(): current_teams_panel.visible = false)

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
		_spawn_ally()

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const ALLY_SCRIPT := preload("res://scripts/ArenaAlly.gd")
const PET_SCENE := preload("res://scenes/Pet.tscn")
const OPPONENT_SPOTS := [Vector2(260, -120), Vector2(340, 80)]
const ALLY_SPOT := Vector2(-320, -60)

func _spawn_pet() -> void:
	if GameManager.equipped_pet == "":
		return
	var pet = PET_SCENE.instantiate()
	pet.pet_id = GameManager.equipped_pet
	add_child(pet)
	pet.global_position = player.global_position + Vector2(-40, 30)

func _spawn_opponents(team_size: int) -> void:
	_opponents_remaining = team_size
	for i in range(team_size):
		var opponent = ENEMY_SCENE.instantiate()
		opponent.is_real_player = true
		# died (not tree_exited) - tree_exited also fires on ordinary scene
		# teardown (e.g. leaving via "Return to Main Menu" while an
		# opponent is still alive), which used to be able to misfire a win.
		opponent.died.connect(_on_opponent_defeated)
		add_child(opponent)
		opponent.global_position = OPPONENT_SPOTS[i % OPPONENT_SPOTS.size()]
		opponent.get_node("Visuals").modulate = Color(1.1, 0.75, 0.75, 1)

# The player's 2v2 teammate - reuses Enemy.tscn's visuals with its
# script swapped to ArenaAlly.gd (set_script() before add_child() so
# ArenaAlly's own _ready() is what actually fires).
func _spawn_ally() -> void:
	var ally = ENEMY_SCENE.instantiate()
	ally.set_script(ALLY_SCRIPT)
	add_child(ally)
	ally.global_position = ALLY_SPOT

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
	GameManager.arena_rank_points += gained
	GameManager.last_arena_rank_points_gained = gained
	# Routes through the normal end_run(true) - is_arena_match being true
	# is what makes it land on ArenaVictory.tscn instead of RaidRewards.tscn
	# (see GameManager.end_run). Arena has no real loot, so the raid-side
	# effects of end_run's success branch (carried_value, loot quests,
	# etc.) are all harmless no-ops here.
	GameManager.end_run(true)

func _open_lilly_panel() -> void:
	lilly_panel.visible = true

func _return_to_main_menu() -> void:
	# Leaving early (before a win/loss fires end_run()) would otherwise
	# leave the player's real gear/pet permanently swapped for whatever
	# Arena Loadout Preset they picked, and is_arena_match stuck true.
	GameManager.end_arena_loadout_if_active()
	GameManager.is_arena_match = false
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")
