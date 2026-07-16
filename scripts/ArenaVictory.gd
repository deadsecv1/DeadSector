extends Control

# Arena's own win screen - replaces the old "toast + 2s wait + straight
# back to Main Menu" flow. Reads GameManager.last_raid_rewards for XP
# (end_run() builds this the same way for every successful run-end,
# Arena included) plus the two Arena-specific fields TheGrid.gd sets
# right before the match ends: last_arena_kills and
# last_arena_rank_points_gained.

@onready var xp_label: Label = $Panel/VBox/XpLabel
@onready var kills_label: Label = $Panel/VBox/KillsLabel
@onready var rank_points_label: Label = $Panel/VBox/RankPointsLabel
@onready var continue_button: Button = $Panel/VBox/ContinueButton

func _ready() -> void:
	GameManager.set_default_cursor()
	var data: Dictionary = GameManager.last_raid_rewards
	xp_label.text = "+%d XP" % int(data.get("xp_gained", 0))
	kills_label.text = "Kills: %d" % GameManager.last_arena_kills
	rank_points_label.text = "+%d Arena Rank points" % GameManager.last_arena_rank_points_gained
	continue_button.pressed.connect(_on_continue)
	GameManager.focus_first_control(self)

func _on_continue() -> void:
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")
