extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const PetTooltipHostScript := preload("res://scripts/PetTooltipHost.gd")
const GodforgedAuraFXScript := preload("res://scripts/GodforgedAuraFX.gd")

signal closed
signal plushie_given(instance_id: String)

# Same tier-ordering convention GamblePanel.gd uses for its own odds
# readout, just built from PLUSHIE_PET_RARITY_WEIGHTS instead of
# CRATE_ODDS - this is a real "here's what you're working with" table,
# not just flavor text, since Multiversal and Divine are genuinely
# reachable through this specific path (see GameManager.
# PLUSHIE_PET_RARITY_WEIGHTS).
const TIER_ORDER := ["rare", "epic", "legendary", "mythic", "exotic", "multiversal", "divine", "godforged"]

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var give_button: Button = $VBox/GiveRow/GiveButton
@onready var odds_label: Label = $VBox/OddsLabel
@onready var owned_title: Label = $VBox/OwnedTitle
@onready var owned_grid: GridContainer = $VBox/OwnedScroll/OwnedGrid
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	give_button.pressed.connect(_on_give_pressed)
	_build_odds_text()

func open() -> void:
	visible = true
	refresh()

func refresh() -> void:
	var plushie_count := _count_plushie_items()
	give_button.text = "Give Plushie (%d in Stash/Backpack)" % plushie_count if plushie_count > 0 else "Give Plushie (none available)"
	give_button.disabled = plushie_count <= 0

	for c in owned_grid.get_children():
		c.queue_free()
	var owned_ids: Array = []
	for id in GameManager.owned_pet_instances:
		if str(id).begins_with("plushie_"):
			owned_ids.append(id)
	owned_title.text = "YOUR PLUSHIE PETS (%d)" % owned_ids.size()
	for id in owned_ids:
		owned_grid.add_child(_make_pet_cell(id))

func _count_plushie_items() -> int:
	var count := 0
	for item in GameManager.stash_items:
		if item.get("slot", "") == "plushie":
			count += 1
	for item in GameManager.backpack_storage:
		if item.get("slot", "") == "plushie":
			count += 1
	return count

func _build_odds_text() -> void:
	var lines: Array = []
	for tier in TIER_ORDER:
		var pct: float = GameManager.PLUSHIE_PET_RARITY_WEIGHTS.get(tier, 0.0)
		# The Godforged sliver (0.0001%) would just print as "0.00%" and
		# read as literally impossible at 2 decimal places - give anything
		# under 0.01% enough precision to actually show up.
		var pct_text: String = ("%.4f%%" % pct) if pct < 0.01 else ("%.2f%%" % pct)
		lines.append("%s: %s" % [GameManager.get_rarity_label(tier), pct_text])
	odds_label.text = " | ".join(lines)

func _on_give_pressed() -> void:
	if not GameManager.has_plushie():
		GameManager.toast_requested.emit("You need a Plushie in your Stash or Backpack Storage first.")
		return
	var instance_id := GameManager.give_plushie_to_rose()
	if instance_id == "":
		GameManager.toast_requested.emit("You need a Plushie in your Stash or Backpack Storage first.")
		return
	plushie_given.emit(instance_id)
	refresh()

func _make_pet_cell(instance_id: String) -> Control:
	var data := GameManager.get_pet_data(instance_id)
	var instance: Dictionary = GameManager.owned_pet_instances.get(instance_id, {})
	var rarity: String = str(instance.get("rarity", "common"))
	var rarity_color := GameManager.get_rarity_color(rarity)
	var is_equipped: bool = GameManager.equipped_pet == instance_id

	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(84, 100)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cell.set_script(PetTooltipHostScript)
	cell.pet_id = instance_id
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.03, 0.85)
	sb.border_color = Color(1.0, 0.85, 0.4, 1) if is_equipped else rarity_color
	sb.set_border_width_all(3 if is_equipped else 2)
	sb.set_corner_radius_all(6)
	cell.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	cell.add_child(vbox)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(0, 56)
	icon_holder.clip_contents = true
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_holder)

	var icon = ItemIconScene.instantiate()
	icon.icon_key = data.get("icon_key", "pet_dog")
	icon.icon_color = data.get("color", Color.WHITE)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon)
	if rarity == "godforged":
		GodforgedAuraFXScript.apply(icon_holder)

	var name_lbl := Label.new()
	name_lbl.text = GameManager.get_pet_display_name(instance_id)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = GameManager.get_rarity_label(rarity)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 10)
	rarity_lbl.add_theme_color_override("font_color", rarity_color)
	rarity_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(rarity_lbl)

	cell.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			GameManager.equip_pet(instance_id)
			refresh()
	)
	return cell
