extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var rumor_label: Label = $VBox/RumorLabel
@onready var reroll_button: Button = $VBox/RerollButton
@onready var tip_button: Button = $VBox/TipButton
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	reroll_button.pressed.connect(_show_new_rumor)
	tip_button.pressed.connect(_on_claim_tip)

func open() -> void:
	visible = true
	_show_new_rumor()
	_refresh_tip_button()
	GameManager.focus_first_control(self)

func _show_new_rumor() -> void:
	var rumors: Array = GameManager.WHISPER_RUMORS
	rumor_label.text = "\"%s\"" % rumors[randi() % rumors.size()]

func _refresh_tip_button() -> void:
	if GameManager.whisper_tip_available():
		tip_button.text = "Take Today's Tip (%d Rubles, %d Artifacts)" % [GameManager.WHISPER_TIP_RUBLES, GameManager.WHISPER_TIP_ARTIFACTS]
		tip_button.disabled = false
	else:
		tip_button.text = "Already Tipped You Today - Come Back Tomorrow"
		tip_button.disabled = true

func _on_claim_tip() -> void:
	if GameManager.claim_whisper_tip():
		_refresh_tip_button()
