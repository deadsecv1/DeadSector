extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if confirm_popup.visible:
			confirm_popup.visible = false
		else:
			closed.emit()

@onready var text_edit: TextEdit = $VBox/TextEdit
@onready var save_button: Button = $VBox/SaveButton
@onready var close_button: Button = $VBox/CloseButton
@onready var confirm_popup: PanelContainer = $ConfirmPopup
@onready var confirm_yes: Button = $ConfirmPopup/Margin/VBox/ButtonRow/YesButton
@onready var confirm_no: Button = $ConfirmPopup/Margin/VBox/ButtonRow/NoButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	confirm_popup.visible = false
	close_button.pressed.connect(func(): closed.emit())
	save_button.pressed.connect(func():
		if text_edit.text.strip_edges() == "":
			GameManager.toast_requested.emit("Write something first")
			return
		confirm_popup.visible = true
	)
	confirm_yes.pressed.connect(func():
		GameManager.submit_feedback(text_edit.text.strip_edges())
		text_edit.text = ""
		confirm_popup.visible = false
		GameManager.toast_requested.emit("Feedback sent - thank you!")
	)
	confirm_no.pressed.connect(func(): confirm_popup.visible = false)

func open() -> void:
	visible = true
	# Same runtime anchor-collapse bug as Flea Market/Mail - force the
	# designed centered layout back explicitly.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -260.0
	offset_top = -270.0
	offset_right = 260.0
	offset_bottom = 270.0
