extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var story_label: Label = $VBox/StoryLabel
@onready var reroll_button: Button = $VBox/RerollButton
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	reroll_button.pressed.connect(_show_new_story)

func open() -> void:
	visible = true
	GameManager._maybe_grant_harmon_welcome()
	_show_new_story()
	GameManager.focus_first_control(self)

func _show_new_story() -> void:
	var stories: Array = GameManager.HARMON_WAR_STORIES
	story_label.text = "\"%s\"" % stories[randi() % stories.size()]
