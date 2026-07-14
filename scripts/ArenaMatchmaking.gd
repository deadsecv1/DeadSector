extends Control

# A brief "matchmaking" beat before dropping into The Grid - same spirit
# as SearchingForPlayers.gd (this is still a simulated experience under
# the hood, no live netcode), randomly settling on a squad size from
# 4v4 up to 7v7.

const SEARCH_SECONDS := 4.0

@onready var spinner: Control = $VBox/Spinner
@onready var mode_label: Label = $VBox/ModeLabel

var _team_size: int = 1

func _ready() -> void:
	GameManager.set_default_cursor()
	_team_size = randi_range(4, 7)
	mode_label.text = "Finding a %dv%d match..." % [_team_size, _team_size]
	spinner.draw.connect(_draw_spinner)
	set_process(true)
	await get_tree().create_timer(SEARCH_SECONDS).timeout
	GameManager.generate_arena_match(_team_size)
	Transition.change_scene("res://scenes/ArenaLoadoutChoice.tscn")

func _process(_delta: float) -> void:
	spinner.queue_redraw()

func _draw_spinner() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var center: Vector2 = spinner.size / 2.0
	var radius: float = spinner.size.x / 2.0 - 4.0
	var segments := 10
	for i in range(segments):
		var ang: float = t * 3.2 + TAU * float(i) / float(segments)
		var alpha: float = 0.15 + 0.75 * (float(i) / float(segments))
		var pos := center + Vector2(cos(ang), sin(ang)) * radius
		spinner.draw_circle(pos, 5.0, Color(0.8, 0.5, 1.0, alpha))
