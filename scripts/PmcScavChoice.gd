extends Control

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var pmc_button: Button = $VBox/CardRow/PmcCard
@onready var scav_button: Button = $VBox/CardRow/ScavCard
@onready var scav_gear_row: HBoxContainer = $VBox/CardRow/ScavCard/ScavVBox/ScavGearRow
@onready var scav_rotation_label: Label = $VBox/CardRow/ScavCard/ScavVBox/ScavRotationLabel
@onready var pmc_gear_row: HBoxContainer = $VBox/CardRow/PmcCard/PmcVBox/PmcGearRow
@onready var back_button: Button = $VBox/BackButton

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		Transition.change_scene_instant("res://scenes/MainMenu.tscn")

func _ready() -> void:
	GameManager.set_default_cursor()
	pmc_button.pressed.connect(_choose_pmc)
	scav_button.pressed.connect(_choose_scav)
	back_button.pressed.connect(func(): Transition.change_scene_instant("res://scenes/MainMenu.tscn"))
	_build_pmc_preview()
	_build_scav_preview()

func _build_pmc_preview() -> void:
	for c in pmc_gear_row.get_children():
		pmc_gear_row.remove_child(c)
		c.queue_free()
	var any_equipped := false
	for slot in ["weapon", "body", "head", "boots", "accessory", "backpack"]:
		var item = GameManager.equipped_items.get(slot)
		if item == null:
			continue
		any_equipped = true
		pmc_gear_row.add_child(_make_gear_icon(item))
	if not any_equipped:
		var lbl := Label.new()
		lbl.text = "(nothing equipped yet)"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.modulate = Color(1, 1, 1, 0.6)
		pmc_gear_row.add_child(lbl)

func _build_scav_preview() -> void:
	for c in scav_gear_row.get_children():
		c.queue_free()
	for slot in ["weapon", "body", "head", "boots"]:
		var item = GameManager.scav_loadout.get(slot)
		if item != null:
			scav_gear_row.add_child(_make_gear_icon(item))
	var secs: float = GameManager.get_trader_rotation_seconds_left()
	var mins := int(secs / 60.0)
	scav_rotation_label.text = "Loadout rotates in %d min" % mins

func _make_gear_icon(item: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(48, 48)
	box.tooltip_text = str(item.get("name", "?"))
	var sb := StyleBoxFlat.new()
	var rarity_color := GameManager.get_rarity_color(item.get("rarity", "common"))
	sb.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18)
	sb.border_color = rarity_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	box.add_theme_stylebox_override("panel", sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = rarity_color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)
	return box

func _choose_pmc() -> void:
	GameManager.start_pmc_run()
	Transition.change_scene("res://scenes/MapChoice.tscn")

func _choose_scav() -> void:
	GameManager.start_scav_run()
	Transition.change_scene("res://scenes/MapChoice.tscn")
