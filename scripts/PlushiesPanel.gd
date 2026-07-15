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
@onready var owned_icon: Control = $VBox/OwnedRow/OwnedIconSlot/Icon
@onready var owned_label: Label = $VBox/OwnedRow/OwnedLabel
@onready var odds_label: Label = $VBox/OddsLabel

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	trade_button.pressed.connect(_on_trade_pressed)

func open() -> void:
	visible = true
	# Same runtime anchor-collapse bug documented elsewhere (Flea Market,
	# Mail, Milestones) - force the designed centered layout back
	# explicitly instead of trusting the .tscn-authored anchors at runtime.
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -190.0
	offset_top = -215.0
	offset_right = 190.0
	offset_bottom = 215.0
	refresh()

func refresh() -> void:
	var plushie_count := _count_plushie_items()
	trade_button.text = "Trade Plushie for Plushie Pet (%d in Stash/Backpack)" % plushie_count if plushie_count > 0 else "Trade Plushie for Plushie Pet (none available)"
	trade_button.disabled = plushie_count <= 0
	odds_label.text = GameManager.get_plushie_pet_odds_text()
	_refresh_owned_pet()

func _refresh_owned_pet() -> void:
	var latest_id := GameManager.get_latest_plushie_pet_instance_id()
	if latest_id == "":
		owned_icon.visible = false
		owned_label.text = "You don't have a Plushie Pet yet."
		return
	var data := GameManager.get_pet_data(latest_id)
	if data.is_empty():
		owned_icon.visible = false
		owned_label.text = "You don't have a Plushie Pet yet."
		return
	owned_icon.visible = true
	owned_icon.icon_key = data.get("icon_key", "generic")
	owned_icon.icon_color = data.get("color", Color.WHITE)
	var rarity: String = data.get("rarity", "rare")
	owned_label.text = "Your latest: %s (%s)" % [data.get("name", "?"), GameManager.get_rarity_label(rarity)]

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
