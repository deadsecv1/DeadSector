extends Control

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var loot_list: VBoxContainer = $Panel/VBox/Scroll/LootList
@onready var back_button: Button = $Panel/VBox/BackButton

func _ready() -> void:
	GameManager.set_default_cursor()
	back_button.pressed.connect(_on_back)
	_build_summary()

func _build_summary() -> void:
	for c in loot_list.get_children():
		loot_list.remove_child(c)
		c.queue_free()

	if GameManager.gauntlet_session_loot.is_empty() and GameManager.gauntlet_session_engrams.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No loot collected this run."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loot_list.add_child(empty_lbl)
		return

	if not GameManager.gauntlet_session_loot.is_empty():
		var header := Label.new()
		header.text = "Loot Collected"
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
		loot_list.add_child(header)
		for item in GameManager.gauntlet_session_loot:
			loot_list.add_child(_make_item_row(item))

	if not GameManager.gauntlet_session_engrams.is_empty():
		var header2 := Label.new()
		header2.text = "Engrams Found"
		header2.add_theme_font_size_override("font_size", 16)
		header2.add_theme_color_override("font_color", Color(0.6, 0.4, 0.9, 1))
		loot_list.add_child(header2)
		for engram in GameManager.gauntlet_session_engrams:
			loot_list.add_child(_make_engram_row(engram))

func _make_item_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(40, 40)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = GameManager.get_rarity_color(item.get("rarity", "common"))
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_box.add_child(icon)
	row.add_child(icon_box)
	var lbl := Label.new()
	lbl.text = "%s (%s)" % [item.get("name", "?"), GameManager.get_rarity_label(item.get("rarity", "common"))]
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", GameManager.get_rarity_color(item.get("rarity", "common")))
	row.add_child(lbl)
	return row

func _make_engram_row(engram: Dictionary) -> Control:
	var lbl := Label.new()
	lbl.text = "◆ %s" % str(engram.get("name", "Engram"))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 0.95, 1))
	return lbl

func _on_back() -> void:
	# Everything collected this run is already in the Backpack - send it
	# all home to the Stash before heading back to the Main Menu.
	for item in GameManager.carried_loot:
		GameManager._add_to_stash(item)
	GameManager.carried_loot.clear()
	GameManager.carried_value = 0
	GameManager.end_gauntlet_session()
	GameManager.save_game()
	Transition.change_scene_instant("res://scenes/MainMenu.tscn")
