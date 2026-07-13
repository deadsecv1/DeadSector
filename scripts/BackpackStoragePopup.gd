extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

# A floating popup for the equipped Backpack's own 7x7 storage,
# reachable via "Open" on the backpack's context menu from anywhere -
# the Stash already shows this grid permanently alongside the main
# inventory, but in-raid and other screens don't have room for that,
# so this gives them the same view/drag/drop on demand.

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var grid: Control = $VBox/GridArea
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	grid.stash_controller = self
	grid.source = "backpack_storage"
	grid.recompute_size()

func open() -> void:
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()

func refresh() -> void:
	for child in grid.get_children():
		child.queue_free()
	var TileScene := preload("res://scenes/InventoryTile.tscn")
	for i in range(GameManager.backpack_storage.size()):
		var item: Dictionary = GameManager.backpack_storage[i]
		var tile = TileScene.instantiate()
		grid.add_child(tile)
		tile.setup(i, item, "backpack_storage")
