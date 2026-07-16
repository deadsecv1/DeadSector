extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

# A floating popup for one of the 4 Specialized Cases (Medical/Gun/Armor/
# Key) - same shape as BackpackStoragePopup.gd, just parameterized by
# case_type instead of being hardcoded to one storage array. set_case_type()
# must be called once, right after instantiating, before open().

signal closed

const CASE_TITLES := {
	"medical": "MEDICAL CASE",
	"gun": "GUN CASE",
	"armor": "ARMOR CASE",
	"key": "KEY CASE",
}
const CASE_HINTS := {
	"medical": "Holds medical consumables - drag them in from your Stash.",
	"gun": "Holds weapons - drag them in from your Stash.",
	"armor": "Holds head, body, and boots armor - drag them in from your Stash.",
	"key": "Holds keys - drag them in from your Stash.",
}

var case_type: String = "medical"

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var title_label: Label = $VBox/Title
@onready var hint_label: Label = $VBox/HintLabel
@onready var grid: Control = $VBox/GridArea
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func set_case_type(p_case_type: String) -> void:
	case_type = p_case_type
	title_label.text = CASE_TITLES.get(case_type, "CASE")
	hint_label.text = CASE_HINTS.get(case_type, "")
	grid.stash_controller = self
	grid.source = "case_" + case_type
	grid.recompute_size()

func open() -> void:
	visible = true
	refresh()
	GameManager.focus_first_control(self)

func refresh() -> void:
	for child in grid.get_children():
		child.queue_free()
	var TileScene := preload("res://scenes/InventoryTile.tscn")
	var items: Array = GameManager.get_case_storage(case_type)
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var tile = TileScene.instantiate()
		grid.add_child(tile)
		tile.setup(i, item, "case_" + case_type)
