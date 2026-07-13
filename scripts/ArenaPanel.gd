extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

# The Arena hub - opened from the Arena main menu button. Describes the
# 1v1/2v2 mode and its map (The Grid), shows your current Arena Rank,
# and hosts the entry points into it: Matchmake (queues into an actual
# match), Find a Team (Arena-flavored version of Social's), Leaderboard
# (the main Leaderboard panel, pre-switched to its Arena tab), and
# Rewards (what each Arena Rank tier is worth).

signal closed
signal matchmake_requested
signal find_team_requested
signal leaderboard_requested
signal rewards_requested

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var rank_icon_slot: Control = $VBox/RankRow/IconSlot
@onready var rank_label: Label = $VBox/RankRow/RankLabel
@onready var matchmake_button: Button = $VBox/MatchmakeButton
@onready var find_team_button: Button = $VBox/FindTeamButton
@onready var leaderboard_button: Button = $VBox/LeaderboardButton
@onready var rewards_button: Button = $VBox/RewardsButton
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	matchmake_button.pressed.connect(func(): matchmake_requested.emit())
	find_team_button.pressed.connect(func(): find_team_requested.emit())
	leaderboard_button.pressed.connect(func(): leaderboard_requested.emit())
	rewards_button.pressed.connect(func(): rewards_requested.emit())

func open() -> void:
	visible = true
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -300.0
	offset_top = -260.0
	offset_right = 300.0
	offset_bottom = 260.0
	_refresh_rank()

func _refresh_rank() -> void:
	for c in rank_icon_slot.get_children():
		c.queue_free()
	var tier: Dictionary = GameManager.get_arena_rank_tier()
	var icon = SmallIconScene.instantiate()
	icon.icon_type = str(tier.get("icon", "star"))
	icon.icon_bg = Color(tier.get("color", Color.WHITE)) * 0.3
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	rank_icon_slot.add_child(icon)
	rank_label.text = "Your Rank: %s" % GameManager.get_arena_rank_display_name()
	rank_label.add_theme_color_override("font_color", tier.get("color", Color.WHITE))
