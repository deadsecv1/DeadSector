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

var _opponents_remaining: int = 0
var _match_won: bool = false

func _ready() -> void:
	GameManager.set_crosshair_cursor()
	player.stats_ready.connect(hud.update_stats)
	player.ammo_changed.connect(hud.update_ammo)
	player._update_ammo_display()
	player.stunned.connect(hud.flash_stun)
	player.health_changed.connect(hud._on_player_health_changed)

	var team_size: int = int(GameManager.current_arena_match.get("team_size", 1))
	_spawn_opponents(team_size)
	if team_size > 1:
		_spawn_ally()

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

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const ALLY_SCRIPT := preload("res://scripts/ArenaAlly.gd")
const OPPONENT_SPOTS := [Vector2(260, -120), Vector2(340, 80)]
const ALLY_SPOT := Vector2(-320, -60)

func _spawn_opponents(team_size: int) -> void:
	_opponents_remaining = team_size
	for i in range(team_size):
		var opponent = ENEMY_SCENE.instantiate()
		opponent.is_real_player = true
		opponent.tree_exited.connect(_on_opponent_defeated)
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
	_opponents_remaining -= 1
	if _opponents_remaining <= 0:
		_win_match()

func _win_match() -> void:
	_match_won = true
	var gained: int = randi_range(60, 140)
	GameManager.arena_rank_points += gained
	GameManager.save_game()
	GameManager.toast_requested.emit("Arena match won! +%d Arena Rank points." % gained)
	await get_tree().create_timer(2.0).timeout
	_return_to_main_menu()

func _open_lilly_panel() -> void:
	lilly_panel.visible = true

func _return_to_main_menu() -> void:
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")
