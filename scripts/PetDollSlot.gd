extends Button

# The Pet slot on the doll. Left-click opens the full My Pets collection
# (every pet you own, including plushie-derived ones, with equip built
# right in) - works the same in the Stash and mid-raid, no navigating
# away needed. Right-click shows a quick Info popup for whichever pet
# is currently equipped - description, when/where it was found, and a
# rename field for hatched pets.

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const PlushieAuraFXScript := preload("res://scripts/PlushieAuraFX.gd")
const MyPetsPanelScene := preload("res://scenes/MyPetsPanel.tscn")

var _pets_panel: Panel = null

func _ready() -> void:
	text = "Pet"
	GameManager.equipped_changed.connect(refresh)
	pressed.connect(_on_left_click)
	gui_input.connect(_on_gui_input)
	refresh()

func _make_custom_tooltip(_for_text: String) -> Control:
	if GameManager.equipped_pet == "":
		return null
	return PetTooltip.build(GameManager.equipped_pet)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_show_info_popup()

func _on_left_click() -> void:
	if _pets_panel != null and is_instance_valid(_pets_panel):
		return
	_pets_panel = MyPetsPanelScene.instantiate()
	get_tree().current_scene.add_child(_pets_panel)
	_pets_panel.closed.connect(func():
		_pets_panel.queue_free()
		_pets_panel = null
		refresh()
	)
	_pets_panel.open()

func refresh() -> void:
	for child in get_children():
		child.queue_free()
	var pet_id: String = GameManager.equipped_pet
	var pet: Dictionary = GameManager.get_pet_data(pet_id)
	if pet_id == "" or pet.is_empty():
		text = "Pet"
		remove_theme_stylebox_override("normal")
		return
	text = ""
	var pet_icon = ItemIconScene.instantiate()
	pet_icon.icon_key = pet.get("icon_key", "generic")
	pet_icon.icon_color = pet.get("color", Color.WHITE)
	pet_icon.anchor_right = 1.0
	pet_icon.anchor_bottom = 1.0
	pet_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pet_icon)

	if pet_id.begins_with("hatched_") or pet_id.begins_with("plushie_") or pet_id.begins_with("pacified_"):
		var instance: Dictionary = GameManager.owned_pet_instances.get(pet_id, {})
		var trait_data := GameManager.get_trait_data(instance.get("trait", ""))
		if trait_data.get("glow", false):
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = GameManager.get_rarity_color(instance.get("rarity", "common"))
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(4)
			add_theme_stylebox_override("normal", sb)
		if trait_data.get("pulse", false):
			var pulse_tw := create_tween()
			pulse_tw.bind_node(pet_icon)
			pulse_tw.set_loops()
			pulse_tw.tween_property(pet_icon, "modulate:a", 0.5, 0.9).set_trans(Tween.TRANS_SINE)
			pulse_tw.tween_property(pet_icon, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
		if trait_data.get("pet_aura", false):
			PlushieAuraFXScript.apply(self, pet.get("color", Color.WHITE))

func _show_info_popup() -> void:
	var pet_id: String = GameManager.equipped_pet
	if pet_id == "":
		GameManager.toast_requested.emit("No Pet equipped")
		return
	var pet: Dictionary = GameManager.get_pet_data(pet_id)
	if pet.is_empty():
		return

	var popup := PopupPanel.new()
	get_tree().current_scene.add_child(popup)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(260, 0)
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = str(pet.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", pet.get("color", Color.WHITE))
	vbox.add_child(name_lbl)

	var is_hatched: bool = pet_id.begins_with("hatched_") or pet_id.begins_with("plushie_") or pet_id.begins_with("pacified_")
	if is_hatched:
		var instance: Dictionary = GameManager.owned_pet_instances.get(pet_id, {})
		var info_lbl := Label.new()
		info_lbl.text = "Rarity: %s\nLevel %d\nFound: %s\nMap: %s" % [
			GameManager.get_rarity_label(instance.get("rarity", "common")), int(instance.get("level", 1)),
			instance.get("found_date", "unknown"), instance.get("found_map", "unknown"),
		]
		info_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(info_lbl)

		var trait_data := GameManager.get_trait_data(instance.get("trait", ""))
		if not trait_data.is_empty():
			var trait_lbl := Label.new()
			trait_lbl.text = "Trait: %s - %s" % [trait_data.get("name", ""), trait_data.get("desc", "")]
			trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			trait_lbl.add_theme_font_size_override("font_size", 11)
			trait_lbl.modulate = Color(1, 0.85, 0.5, 1)
			vbox.add_child(trait_lbl)

		var rename_row := HBoxContainer.new()
		rename_row.add_theme_constant_override("separation", 6)
		vbox.add_child(rename_row)
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Rename..."
		name_edit.text = instance.get("custom_name", "")
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rename_row.add_child(name_edit)
		var save_btn := Button.new()
		save_btn.text = "Save"
		save_btn.pressed.connect(func():
			GameManager.rename_pet(pet_id, name_edit.text)
			refresh()
			popup.hide()
			popup.queue_free()
		)
		rename_row.add_child(save_btn)
	else:
		var quote_lbl := Label.new()
		quote_lbl.text = str(pet.get("quote", ""))
		quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		quote_lbl.add_theme_font_size_override("font_size", 12)
		quote_lbl.modulate = Color(1, 1, 1, 0.75)
		vbox.add_child(quote_lbl)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): popup.hide(); popup.queue_free())
	vbox.add_child(close_btn)

	popup.popup_centered()
