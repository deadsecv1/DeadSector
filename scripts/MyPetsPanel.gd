extends Panel
const PlushieAuraFXScript := preload("res://scripts/PlushieAuraFX.gd")
const PetTooltipHostScript := preload("res://scripts/PetTooltipHost.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var grid: GridContainer = $VBox/Scroll/Grid
@onready var close_button: Button = $VBox/CloseButton
@onready var info_popup: Panel = $InfoPopup
@onready var info_backdrop: ColorRect = $InfoPopup/Backdrop
@onready var info_icon_slot: Control = $InfoPopup/VBox/IconSlot
@onready var info_name: Label = $InfoPopup/VBox/NameLabel
@onready var info_rarity: Label = $InfoPopup/VBox/RarityLabel
@onready var info_level: Label = $InfoPopup/VBox/LevelLabel
@onready var info_date: Label = $InfoPopup/VBox/DateLabel
@onready var info_trait_name: Label = $InfoPopup/VBox/TraitBox/TraitName
@onready var info_trait_desc: Label = $InfoPopup/VBox/TraitBox/TraitDesc
@onready var info_equip_button: Button = $InfoPopup/VBox/EquipButton
@onready var info_close_button: Button = $InfoPopup/VBox/InfoCloseButton

var current_info_id: String = ""

func _ready() -> void:
	visible = false
	# Full-screen panel (fills the whole viewport) - no draggable edges here, unlike the smaller centered popups.
	info_popup.visible = false
	close_button.pressed.connect(func(): closed.emit())
	info_close_button.pressed.connect(func(): info_popup.visible = false)
	info_equip_button.pressed.connect(_on_equip_from_info)

func open() -> void:
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()

func refresh() -> void:
	for c in grid.get_children():
		c.queue_free()
	if GameManager.owned_pet_instances.is_empty():
		grid.columns = 1
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.custom_minimum_size = Vector2(0, 140)
		var lbl := Label.new()
		lbl.text = "No pets hatched yet.\nDeposit an Egg in the Hatchery to get started."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.custom_minimum_size = Vector2(320, 0)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.modulate = Color(1, 1, 1, 0.75)
		center.add_child(lbl)
		grid.add_child(center)
		return
	grid.columns = 6
	for instance_id in GameManager.owned_pet_instances:
		grid.add_child(_make_pet_cell(instance_id))

func _make_pet_cell(instance_id: String) -> Control:
	var data := GameManager.get_pet_data(instance_id)
	var instance: Dictionary = GameManager.owned_pet_instances.get(instance_id, {})
	var rarity: String = instance.get("rarity", "common")
	var rarity_color := GameManager.get_rarity_color(rarity)
	var trait_data := GameManager.get_trait_data(instance.get("trait", ""))
	var is_prismatic: bool = trait_data.get("prismatic", false)
	var has_glow: bool = trait_data.get("glow", false)

	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(84, 100)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cell.set_script(PetTooltipHostScript)
	cell.pet_id = instance_id
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.03, 0.85)
	sb.border_color = rarity_color
	sb.set_border_width_all(3 if has_glow else 2)
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

	# Rare-trait pets pulse gently right in the list, not just in-game -
	# a constant, subtle signal that this one is special.
	if trait_data.get("pulse", false):
		var pulse_tw := icon.create_tween()
		pulse_tw.bind_node(icon)
		pulse_tw.set_loops()
		pulse_tw.tween_property(icon, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
		pulse_tw.tween_property(icon, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)

	if trait_data.get("pet_aura", false):
		PlushieAuraFXScript.apply(icon_holder, data.get("color", Color.WHITE))

	var name_lbl := Label.new()
	name_lbl.text = data.get("name", "?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = GameManager.get_rarity_label(rarity)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 9)
	rarity_lbl.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(rarity_lbl)

	if is_prismatic:
		var trait_tag := Label.new()
		trait_tag.text = "★ " + trait_data.get("name", "")
		trait_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		trait_tag.add_theme_font_size_override("font_size", 8)
		trait_tag.clip_text = true
		var tag_tw := trait_tag.create_tween()
		tag_tw.bind_node(trait_tag)
		tag_tw.set_loops()
		tag_tw.tween_property(trait_tag, "modulate", Color(1.0, 0.4, 0.9, 1), 0.6)
		tag_tw.tween_property(trait_tag, "modulate", Color(0.4, 0.8, 1.0, 1), 0.6)
		tag_tw.tween_property(trait_tag, "modulate", Color(1.0, 0.9, 0.3, 1), 0.6)
		vbox.add_child(trait_tag)

	cell.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_open_info(instance_id)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_open_context_menu(instance_id, event.global_position)
	)
	return cell

func _open_context_menu(instance_id: String, at_position: Vector2) -> void:
	var data := GameManager.get_pet_data(instance_id)
	var menu := PopupMenu.new()
	get_tree().current_scene.add_child(menu)
	var is_equipped: bool = GameManager.equipped_pet == instance_id
	menu.add_item("Info", 0)
	menu.add_item("Equipped" if is_equipped else "Equip", 1)
	menu.set_item_disabled(1, is_equipped)
	menu.add_item("Inspect", 2)
	menu.id_pressed.connect(func(id: int):
		match id:
			0, 2:
				_open_info(instance_id)
			1:
				GameManager.equip_pet(instance_id)
				GameManager.toast_requested.emit("%s equipped!" % data.get("name", "Pet"))
				refresh()
	)
	menu.popup_hide.connect(func(): menu.queue_free())
	menu.position = Vector2i(at_position)
	menu.popup()

func _open_info(instance_id: String) -> void:
	current_info_id = instance_id
	var data := GameManager.get_pet_data(instance_id)
	var instance: Dictionary = GameManager.owned_pet_instances.get(instance_id, {})
	var rarity: String = instance.get("rarity", "common")
	var rarity_color := GameManager.get_rarity_color(rarity)
	var trait_data := GameManager.get_trait_data(instance.get("trait", ""))

	for c in info_icon_slot.get_children():
		c.queue_free()
	var icon = ItemIconScene.instantiate()
	icon.icon_key = data.get("icon_key", "pet_dog")
	icon.icon_color = data.get("color", Color.WHITE)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	info_icon_slot.add_child(icon)
	if trait_data.get("pulse", false):
		var pulse_tw := icon.create_tween()
		pulse_tw.bind_node(icon)
		pulse_tw.set_loops()
		pulse_tw.tween_property(icon, "modulate:a", 0.5, 0.8).set_trans(Tween.TRANS_SINE)
		pulse_tw.tween_property(icon, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	if trait_data.get("pet_aura", false):
		PlushieAuraFXScript.apply(info_icon_slot, data.get("color", Color.WHITE))

	info_name.text = data.get("name", "?")
	info_name.add_theme_color_override("font_color", rarity_color)
	info_rarity.text = GameManager.get_rarity_label(rarity)
	info_rarity.add_theme_color_override("font_color", rarity_color)
	info_level.text = "Level %d" % int(instance.get("level", 1))
	info_date.text = "Hatched %s in %s" % [instance.get("found_date", "?"), instance.get("found_map", "?")]

	if not trait_data.is_empty():
		info_trait_name.text = "Trait: %s" % trait_data.get("name", "")
		info_trait_desc.text = trait_data.get("desc", "")
		var tier: String = trait_data.get("tier", "common")
		var tier_colors := {
			"common": Color(0.8, 0.8, 0.8, 1), "uncommon": Color(0.4, 0.9, 0.5, 1),
			"rare": Color(0.3, 0.6, 1.0, 1), "epic": Color(0.7, 0.35, 0.95, 1), "mythic": Color(1.0, 0.5, 0.15, 1),
		}
		info_trait_name.add_theme_color_override("font_color", tier_colors.get(tier, Color.WHITE))
		if trait_data.get("prismatic", false):
			var name_tw := info_trait_name.create_tween()
			name_tw.bind_node(info_trait_name)
			name_tw.set_loops()
			name_tw.tween_property(info_trait_name, "modulate", Color(1.0, 0.4, 0.9, 1), 0.6)
			name_tw.tween_property(info_trait_name, "modulate", Color(0.4, 0.8, 1.0, 1), 0.6)
			name_tw.tween_property(info_trait_name, "modulate", Color(1.0, 0.9, 0.3, 1), 0.6)
	else:
		info_trait_name.text = "No trait"
		info_trait_desc.text = ""

	var is_equipped: bool = GameManager.equipped_pet == instance_id
	info_equip_button.text = "Equipped" if is_equipped else "Equip"
	info_equip_button.disabled = is_equipped

	info_popup.visible = true

func _on_equip_from_info() -> void:
	if current_info_id == "":
		return
	GameManager.equip_pet(current_info_id)
	var data := GameManager.get_pet_data(current_info_id)
	GameManager.toast_requested.emit("%s equipped!" % data.get("name", "Pet"))
	info_equip_button.text = "Equipped"
	info_equip_button.disabled = true
	refresh()
