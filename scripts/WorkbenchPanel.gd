extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const RECIPE_ICONS := {
	"bandage": "medical", "reinforced_vest": "gear", "scrap_smg": "combat", "utility_belt": "gear",
}

@onready var list: VBoxContainer = $VBox/ListScroll/RecipeList
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	refresh()
	GameManager.focus_first_control(self)

func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	for recipe in GameManager.CRAFTING_RECIPES:
		list.add_child(_make_row(recipe))

func _make_row(recipe: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 84)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var icon = SmallIconScene.instantiate()
	icon.icon_type = RECIPE_ICONS.get(recipe.get("id", ""), "gear")
	icon.custom_minimum_size = Vector2(30, 30)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = recipe.get("name", "?")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(name_lbl)

	var recipe_id: String = recipe.get("id", "")
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 40)
	btn.text = "Craft"
	btn.disabled = not GameManager.can_craft(recipe_id)
	btn.pressed.connect(func():
		GameManager.craft_item(recipe_id)
		refresh()
	)
	hbox.add_child(btn)
	vbox.add_child(hbox)

	var mats_lbl := Label.new()
	var parts: Array = []
	var materials: Dictionary = recipe.get("materials", {})
	for mat_name in materials.keys():
		var needed: int = int(materials[mat_name])
		var have: int = GameManager.count_stash_material(mat_name)
		parts.append("%s %d/%d" % [mat_name, have, needed])
	mats_lbl.text = "Needs: " + ", ".join(parts)
	mats_lbl.add_theme_font_size_override("font_size", 12)
	mats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	mats_lbl.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(mats_lbl)

	return row
