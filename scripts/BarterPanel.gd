extends Control

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const RECIPE_ICONS := {
	"gpcoin_to_btc": "money", "batteries_to_filter": "tech", "scraps_to_plate": "gear", "bundle_to_vest": "gear",
}

@onready var list: VBoxContainer = $VBox/ListScroll/List
@onready var back_button: Button = $VBox/BackButton

func _ready() -> void:
	back_button.pressed.connect(func(): Transition.change_scene_instant("res://scenes/Traders.tscn"))
	refresh()

func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	for recipe in GameManager.BARTER_RECIPES:
		list.add_child(_make_row(recipe))

func _make_row(recipe: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 86)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	row.add_child(vbox)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var icon = SmallIconScene.instantiate()
	icon.icon_type = RECIPE_ICONS.get(recipe.get("id", ""), "money")
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
	btn.custom_minimum_size = Vector2(110, 40)
	btn.text = "Barter"
	btn.disabled = not GameManager.can_barter(recipe_id)
	btn.pressed.connect(func():
		GameManager.do_barter(recipe_id)
		refresh()
	)
	hbox.add_child(btn)
	vbox.add_child(hbox)

	var give_lbl := Label.new()
	var parts: Array = []
	var give: Dictionary = recipe.get("give", {})
	for item_name in give.keys():
		var needed: int = int(give[item_name])
		var have: int = GameManager.count_stash_material(item_name)
		parts.append("%s %d/%d" % [item_name, have, needed])
	give_lbl.text = "Give: " + ", ".join(parts)
	give_lbl.add_theme_font_size_override("font_size", 12)
	give_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	give_lbl.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(give_lbl)

	var receive: Dictionary = recipe.get("receive", {})
	var receive_lbl := Label.new()
	receive_lbl.text = "Receive: %s (%s)" % [receive.get("name", "?"), String(receive.get("rarity", "common")).capitalize()]
	receive_lbl.add_theme_font_size_override("font_size", 12)
	receive_lbl.add_theme_color_override("font_color", GameManager.get_rarity_color(receive.get("rarity", "common")))
	vbox.add_child(receive_lbl)

	return row
