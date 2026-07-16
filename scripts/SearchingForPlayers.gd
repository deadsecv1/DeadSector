extends Control

# A brief "matchmaking" beat between picking Day/Night Raid and actually
# loading in - purely atmospheric (this is still a solo/simulated-scav
# experience under the hood), but it sells the idea that the Sector has
# other operatives in it. Always exactly SEARCH_SECONDS, then routes to
# whatever MapSelect._start_raid used to route to directly: the Recruit
# Select screen if unlocked, otherwise straight into the raid.

const SEARCH_SECONDS := 5.0

@onready var spinner: Control = $VBox/Spinner
@onready var ranked_label: Label = $VBox/RankedLabel

func _ready() -> void:
	GameManager.set_default_cursor()
	GameManager.begin_raid_session()
	ranked_label.visible = GameManager.is_ranked_match
	spinner.draw.connect(_draw_spinner)
	set_process(true)
	GameManager.focus_first_control(self)
	await get_tree().create_timer(SEARCH_SECONDS).timeout
	_proceed()

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
		spinner.draw_circle(pos, 5.0, Color(0.85, 0.75, 0.4, alpha))

func _proceed() -> void:
	if GameManager.recruit_raid_unlocked() and not GameManager.is_scav_run:
		Transition.change_scene_instant("res://scenes/RecruitSelect.tscn")
	else:
		GameManager.selected_recruit = ""
		var scene_path: String = GameManager.MAP_SCENES.get(GameManager.selected_map, "res://scenes/Main.tscn")
		Transition.change_scene(scene_path)
