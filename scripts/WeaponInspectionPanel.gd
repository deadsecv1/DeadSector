extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

signal closed
# Emitted so the screen that owns this panel (Stash.gd) can forward to its
# own already-existing SkinsPanel, the same way ItemContextMenu.gd's own
# skins_requested signal already works - this panel doesn't own a second
# copy of that browser, it just asks for the existing one.
signal skins_requested(item: Dictionary)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()
		_close_hotspot_menu()

const SLOT_ORDER := ["scope", "barrel", "laser", "mag", "grip"]
const SLOT_LABELS := {
	"scope": "Scope", "mag": "Magazine", "barrel": "Barrel",
	"grip": "Grip", "laser": "Laser",
}
# Rough mount points over a ~480x200 Showcase - not tied to any one
# weapon's real silhouette (there's no per-weapon hotspot data to draw
# from), just a consistent, plausible-looking spread that reads fine
# across every weapon sprite/icon, all roughly landscape-shaped.
const HOTSPOT_OFFSETS := {
	"scope": Vector2(300, 30),
	"barrel": Vector2(430, 85),
	"laser": Vector2(390, 128),
	"mag": Vector2(250, 152),
	"grip": Vector2(165, 140),
}
const EMPTY_DOT_COLOR := Color(0.4, 0.4, 0.44, 1)

@onready var title_label: Label = $VBox/TitleLabel
@onready var rarity_label: Label = $VBox/RarityLabel
@onready var showcase: Control = $VBox/Showcase
@onready var external_art: TextureRect = $VBox/Showcase/ExternalArt
@onready var hint_label: Label = $VBox/HintLabel
@onready var skins_button: Button = $VBox/ButtonRow/SkinsButton
@onready var close_button: Button = $VBox/ButtonRow/CloseButton

var icon_node: Control = null
var weapon_index: int = -1
var weapon_source: String = "carried"
var hotspot_buttons: Dictionary = {}
var hotspot_menu: PanelContainer = null

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func():
		_close_hotspot_menu()
		closed.emit()
	)
	skins_button.pressed.connect(func():
		var weapon := _get_weapon()
		if not weapon.is_empty():
			skins_requested.emit(weapon)
	)
	for slot_key in SLOT_ORDER:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(26, 26)
		btn.size = Vector2(26, 26)
		btn.position = HOTSPOT_OFFSETS[slot_key] - Vector2(13, 13)
		btn.tooltip_text = SLOT_LABELS.get(slot_key, slot_key.capitalize())
		var sb := StyleBoxFlat.new()
		sb.bg_color = EMPTY_DOT_COLOR
		sb.set_corner_radius_all(13)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.05, 0.05, 0.06, 0.9)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.pressed.connect(func(): _open_hotspot_menu(slot_key))
		showcase.add_child(btn)
		hotspot_buttons[slot_key] = btn
	GameManager.equipped_changed.connect(func():
		if visible:
			refresh()
	)

func open_for(index: int, source: String) -> void:
	weapon_index = index
	weapon_source = source
	visible = true
	refresh()

func _source_array() -> Array:
	return GameManager.carried_loot if weapon_source == "carried" else GameManager.stash_items

func _get_weapon() -> Dictionary:
	var arr := _source_array()
	if weapon_index < 0 or weapon_index >= arr.size():
		return {}
	var item: Dictionary = arr[weapon_index]
	# Sort (and anything else that reorders source_array while this panel
	# is left open) can shift a completely different item into this index -
	# without this check, buying/installing an attachment would graft an
	# "attachments" dict onto whatever that item happens to be (even a
	# stack of bandages) and spend real Rubles doing it.
	if item.get("slot", "") != "weapon":
		return {}
	return item

func refresh() -> void:
	_close_hotspot_menu()
	var weapon := _get_weapon()
	if weapon.is_empty():
		title_label.text = "Weapon not found"
		rarity_label.text = "It may have moved."
		for slot_key in SLOT_ORDER:
			hotspot_buttons[slot_key].visible = false
		external_art.visible = false
		if icon_node != null and is_instance_valid(icon_node):
			icon_node.visible = false
		return

	title_label.text = weapon.get("name", "?")
	var rarity: String = weapon.get("rarity", "common")
	rarity_label.text = GameManager.get_rarity_label(rarity)
	var display_color: Color = GameManager.get_display_color(weapon)
	rarity_label.add_theme_color_override("font_color", display_color)

	var icon_key: String = weapon.get("icon_key", "pistol")
	var art_path := "res://assets/weapons/%s.png" % icon_key
	if ResourceLoader.exists(art_path):
		external_art.texture = load(art_path)
		external_art.modulate = display_color
		external_art.visible = true
		if icon_node != null and is_instance_valid(icon_node):
			icon_node.visible = false
	else:
		external_art.visible = false
		if icon_node == null or not is_instance_valid(icon_node):
			icon_node = ItemIconScene.instantiate()
			icon_node.anchor_left = 0.5
			icon_node.anchor_top = 0.5
			icon_node.anchor_right = 0.5
			icon_node.anchor_bottom = 0.5
			icon_node.offset_left = -70
			icon_node.offset_top = -70
			icon_node.offset_right = 70
			icon_node.offset_bottom = 70
			icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			showcase.add_child(icon_node)
			showcase.move_child(icon_node, 0)
		icon_node.visible = true
		icon_node.icon_key = icon_key
		icon_node.icon_color = display_color
		icon_node.queue_redraw()

	var attachments := GameManager.get_weapon_attachments_for(weapon)
	for slot_key in SLOT_ORDER:
		var btn: Button = hotspot_buttons[slot_key]
		btn.visible = true
		var installed = attachments.get(slot_key)
		var sb: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate()
		sb.bg_color = GameManager.get_rarity_color(installed.get("rarity", "common")) if installed != null else EMPTY_DOT_COLOR
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.tooltip_text = "%s: %s" % [SLOT_LABELS.get(slot_key, slot_key), installed.get("name", "Empty") if installed != null else "Empty"]

# --- Per-slot hotspot menu: shows the installed attachment (if any) with
# a Remove option, then every ATTACHMENT_POOL entry for that slot - Equip
# if a spare one is already sitting in this weapon's own source array
# (Backpack/Stash), otherwise Buy (spends Rubles via GameManager.
# buy_attachment_for_weapon(), a new acquisition path - attachments used
# to only ever come from loot). Built fresh each time rather than reused/
# hidden, same reasoning as Stash.gd's own stats popup: simplest way to
# guarantee it never shows stale state after an equip/remove/buy.
func _close_hotspot_menu() -> void:
	if is_instance_valid(hotspot_menu):
		hotspot_menu.queue_free()
	hotspot_menu = null

func _open_hotspot_menu(slot_key: String) -> void:
	_close_hotspot_menu()
	var weapon := _get_weapon()
	if weapon.is_empty():
		return
	var is_carried: bool = weapon_source == "carried"
	var source_array := _source_array()
	var attachments := GameManager.get_weapon_attachments_for(weapon)
	var installed = attachments.get(slot_key)

	hotspot_menu = PanelContainer.new()
	hotspot_menu.z_index = 260
	hotspot_menu.custom_minimum_size = Vector2(260, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.08, 0.98)
	sb.border_color = Color(0.6, 0.9, 0.6, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	hotspot_menu.add_theme_stylebox_override("panel", sb)
	hotspot_menu.anchor_left = 0.5
	hotspot_menu.anchor_top = 0.5
	hotspot_menu.anchor_right = 0.5
	hotspot_menu.anchor_bottom = 0.5
	hotspot_menu.offset_left = -130
	hotspot_menu.offset_right = 130
	hotspot_menu.offset_top = -10

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	hotspot_menu.add_child(vbox)

	var title := Label.new()
	title.text = "%s SLOT" % SLOT_LABELS.get(slot_key, slot_key.capitalize()).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	if installed != null:
		var row := _make_menu_row(installed.get("name", "?"), "Installed", "Remove", func():
			GameManager.remove_attachment_from_item(weapon, slot_key, source_array, is_carried)
			refresh()
			_open_hotspot_menu(slot_key)
		)
		vbox.add_child(row)
		vbox.add_child(HSeparator.new())

	for pool_entry in GameManager.ATTACHMENT_POOL:
		if pool_entry.get("attachment_slot", "") != slot_key:
			continue
		var is_this_installed: bool = installed != null and installed.get("name", "") == pool_entry.get("name", "")
		var owned_index := _find_owned_attachment(source_array, pool_entry)
		var stat_text := GameManager.get_armor_effect_text("", "") # placeholder, overwritten below
		stat_text = "+%s %s" % [str(pool_entry.get("stat_value", 0.0)), str(pool_entry.get("stat_type", "")).capitalize()]
		if is_this_installed:
			vbox.add_child(_make_menu_row(pool_entry.get("name", "?"), stat_text, "Equipped", Callable(), true))
		elif owned_index >= 0:
			vbox.add_child(_make_menu_row(pool_entry.get("name", "?"), "%s - owned" % stat_text, "Equip", func():
				GameManager.install_attachment_on_item(weapon, source_array, owned_index, is_carried)
				refresh()
				_open_hotspot_menu(slot_key)
			))
		else:
			var cost: int = int(pool_entry.get("value", 0))
			vbox.add_child(_make_menu_row(pool_entry.get("name", "?"), "%s - %d Rubles" % [stat_text, cost], "Buy", func():
				GameManager.buy_attachment_for_weapon(weapon, pool_entry, source_array, is_carried)
				refresh()
				_open_hotspot_menu(slot_key)
			))

	var close_btn := Button.new()
	close_btn.custom_minimum_size = Vector2(0, 34)
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_hotspot_menu)
	vbox.add_child(close_btn)

	add_child(hotspot_menu)

func _find_owned_attachment(source_array: Array, pool_entry: Dictionary) -> int:
	for i in range(source_array.size()):
		var item = source_array[i]
		if item.get("slot", "") == "attachment" and item.get("name", "") == pool_entry.get("name", ""):
			return i
	return -1

func _make_menu_row(name_text: String, sub_text: String, button_text: String, on_press: Callable, disabled: bool = false) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var label_box := VBoxContainer.new()
	label_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = name_text
	title.add_theme_font_size_override("font_size", 14)
	label_box.add_child(title)
	var sub := Label.new()
	sub.text = sub_text
	sub.add_theme_font_size_override("font_size", 11)
	sub.modulate = Color(1, 1, 1, 0.7)
	label_box.add_child(sub)
	hbox.add_child(label_box)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(84, 40)
	btn.text = button_text
	btn.disabled = disabled
	if on_press.is_valid():
		btn.pressed.connect(on_press)
	hbox.add_child(btn)
	return row
