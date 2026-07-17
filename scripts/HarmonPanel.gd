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
	# Force the designed centered rect back explicitly - since this panel
	# is draggable (DraggablePanelScript.apply() above), a drag from a
	# previous open persists in .offset_*/.position indefinitely (this
	# node stays alive, just hidden, between opens) unless reset here.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -260.0
	offset_top = -190.0
	offset_right = 260.0
	offset_bottom = 190.0
	GameManager._maybe_grant_harmon_welcome()
	_show_new_story()
	GameManager.focus_first_control(self)
	PanelOpenFX.animate_open(self)

func _show_new_story() -> void:
	var stories: Array = GameManager.HARMON_WAR_STORIES
	story_label.text = "\"%s\"" % stories[randi() % stories.size()]
