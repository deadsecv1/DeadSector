extends Control

# Arena's own loss screen - deliberately much lighter than the normal
# raid DeathScreen (no mannequin/hit-location review, no attacker info):
# losing an Arena match isn't a real death with real stakes, it's just
# "that match is over," so the message says exactly that instead of
# reusing DeathScreen's much heavier framing.

@onready var kills_label: Label = $Panel/VBox/KillsLabel
@onready var continue_button: Button = $Panel/VBox/ContinueButton

func _ready() -> void:
	GameManager.set_default_cursor()
	kills_label.text = "Kills: %d" % GameManager.last_arena_kills
	continue_button.pressed.connect(_on_continue)
	GameManager.focus_first_control(self)

func _on_continue() -> void:
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")
