extends Control

@onready var day_button: Button = $VBox/DayButton
@onready var night_button: Button = $VBox/NightButton
@onready var day_time_label: Label = $VBox/DayTimeLabel
@onready var night_time_label: Label = $VBox/NightTimeLabel
@onready var back_button: Button = $VBox/BackButton

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		Transition.change_scene_instant("res://scenes/MapChoice.tscn")

func _ready() -> void:
	GameManager.set_default_cursor()
	day_button.pressed.connect(func(): _start_raid(false))
	night_button.pressed.connect(func(): _start_raid(true))
	back_button.pressed.connect(func(): Transition.change_scene_instant("res://scenes/MapChoice.tscn"))
	_update_time()

func _process(_delta: float) -> void:
	_update_time()

func _update_time() -> void:
	day_time_label.text = "Currently %s" % GameManager.format_hour(GameManager.get_day_display_hour())
	night_time_label.text = "Currently %s" % GameManager.format_hour(GameManager.get_night_display_hour())

func _start_raid(is_night: bool) -> void:
	GameManager.is_night_raid = is_night
	GameManager.selected_raid_hour = GameManager.get_night_display_hour() if is_night else GameManager.get_day_display_hour()
	Transition.change_scene_instant("res://scenes/SearchingForPlayers.tscn")
