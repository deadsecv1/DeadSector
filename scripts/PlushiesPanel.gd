extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed
signal plushie_given(instance_id: String)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var trade_button: Button = $VBox/TradeButton
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	trade_button.pressed.connect(_on_trade_pressed)

func open() -> void:
	visible = true
	refresh()

func refresh() -> void:
	var plushie_count := _count_plushie_items()
	trade_button.text = "Trade Plushie for Plushie Pet (%d in Stash/Backpack)" % plushie_count if plushie_count > 0 else "Trade Plushie for Plushie Pet (none available)"
	trade_button.disabled = plushie_count <= 0

func _count_plushie_items() -> int:
	var count := 0
	for item in GameManager.stash_items:
		if item.get("slot", "") == "plushie":
			count += 1
	for item in GameManager.backpack_storage:
		if item.get("slot", "") == "plushie":
			count += 1
	return count

func _on_trade_pressed() -> void:
	if not GameManager.has_plushie():
		GameManager.toast_requested.emit("You need a Plushie in your Stash or Backpack Storage first.")
		return
	var instance_id := GameManager.give_plushie_to_rose()
	if instance_id == "":
		GameManager.toast_requested.emit("You need a Plushie in your Stash or Backpack Storage first.")
		return
	plushie_given.emit(instance_id)
	refresh()
