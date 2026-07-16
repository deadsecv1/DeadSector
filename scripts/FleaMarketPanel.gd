extends Panel

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")

@onready var coins_label: Label = $VBox/CoinsLabel
@onready var listing_list: VBoxContainer = $VBox/Panels/ListCol/ListVBox/ListScroll/ListingList
@onready var mine_list: VBoxContainer = $VBox/Panels/MineCol/MineVBox/MineScroll/MineList
@onready var browse_list: VBoxContainer = $VBox/Panels/BrowseCol/BrowseVBox/BrowseScroll/BrowseList
@onready var sort_button: Button = $VBox/Panels/BrowseCol/BrowseVBox/BrowseTitleRow/SortButton
@onready var category_row: HBoxContainer = $VBox/Panels/BrowseCol/BrowseVBox/CategoryScroll/CategoryRow
@onready var close_button: Button = $VBox/CloseButton

# Gear-type categories for the Browse Market filter - label to the slot
# value it matches, empty string meaning "no filter, show everything".
const BROWSE_CATEGORIES := [
	["All", ""], ["Weapon", "weapon"], ["Chestplate", "body"], ["Helmet", "head"],
	["Boots", "boots"], ["Backpack", "backpack"], ["Tactical Accessory", "accessory"], ["Pet Eggs", "egg"],
	["Ammo", "ammo"], ["Helmet Attachments", "helmet_attachment"],
]
var _browse_category_filter: String = ""
var _browse_sort_by_rarity: bool = false
var _category_buttons: Dictionary = {}

var _price_edits: Dictionary = {} # stash_index -> LineEdit
var _mine_countdowns: Array = [] # {"expire_at": float, "label": Label}
var _countdown_timer: float = 0.0

func _ready() -> void:
	visible = false
	# Full-screen panel (fills the whole viewport) - no draggable edges here, unlike the smaller centered popups.
	close_button.pressed.connect(func(): closed.emit())
	# A listing can resolve (sold/expired) in the background while this
	# panel is sitting open - without this, "My Listings" kept showing a
	# live countdown and a Cancel button for something already gone.
	GameManager.flea_market_changed.connect(func():
		if visible:
			refresh()
	)
	sort_button.pressed.connect(func():
		_browse_sort_by_rarity = not _browse_sort_by_rarity
		sort_button.text = "Sort: Rarity ✓" if _browse_sort_by_rarity else "Sort: Rarity"
		refresh()
	)
	for cat in BROWSE_CATEGORIES:
		var label: String = cat[0]
		var slot_value: String = cat[1]
		var btn := Button.new()
		btn.text = label
		btn.custom_minimum_size = Vector2(0, 28)
		btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true
		btn.button_pressed = (slot_value == _browse_category_filter)
		btn.pressed.connect(func():
			_browse_category_filter = slot_value
			for c in _category_buttons:
				_category_buttons[c].button_pressed = (c == slot_value)
			refresh()
		)
		category_row.add_child(btn)
		_category_buttons[slot_value] = btn

func open() -> void:
	visible = true
	# This panel's anchors were reading back as 0,0,0,0 at runtime instead
	# of the 0,0,1,1 (full-rect) set in the .tscn - reproducible even
	# after a full editor-cache wipe, so something about how this specific
	# instanced sub-scene resolves its root layout isn't taking. Forcing
	# it explicitly here is a direct, reliable fix regardless of that
	# underlying cause.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameManager._check_flea_market()
	refresh()
	set_process(true)

func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_countdown_timer += delta
	if _countdown_timer >= 1.0:
		_countdown_timer = 0.0
		for entry in _mine_countdowns:
			if is_instance_valid(entry["label"]):
				entry["label"].text = "Expires in %s" % _countdown_text(entry["expire_at"])

func refresh() -> void:
	coins_label.text = "Your Rubles: %d" % GameManager.rubles
	_price_edits.clear()

	for c in listing_list.get_children():
		listing_list.remove_child(c)
		c.queue_free()
	if GameManager.stash_items.is_empty():
		var lbl := Label.new()
		lbl.text = "Nothing in your Stash to list."
		lbl.modulate = Color(1, 1, 1, 0.6)
		listing_list.add_child(lbl)
	else:
		for i in range(GameManager.stash_items.size()):
			listing_list.add_child(_make_list_row(i))

	for c in mine_list.get_children():
		mine_list.remove_child(c)
		c.queue_free()
	_mine_countdowns.clear()
	var mine: Array = GameManager.flea_market_listings.filter(func(l): return l.get("is_player", false))
	if mine.is_empty():
		var lbl2 := Label.new()
		lbl2.text = "You don't have anything listed right now."
		lbl2.modulate = Color(1, 1, 1, 0.6)
		mine_list.add_child(lbl2)
	else:
		for l in mine:
			mine_list.add_child(_make_mine_row(l))

	for c in browse_list.get_children():
		browse_list.remove_child(c)
		c.queue_free()
	var others: Array = GameManager.flea_market_listings.filter(func(l): return not l.get("is_player", false))
	if _browse_category_filter != "":
		others = others.filter(func(l): return str(l.get("item", {}).get("slot", "")) == _browse_category_filter)
	if _browse_sort_by_rarity:
		var rarity_order: Array = GameManager.RARITY_TIERS.keys()
		others.sort_custom(func(a, b):
			var ra: int = rarity_order.find(str(a.get("item", {}).get("rarity", "common")))
			var rb: int = rarity_order.find(str(b.get("item", {}).get("rarity", "common")))
			return ra > rb
		)
	if others.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nothing matching that filter right now."
		empty_lbl.modulate = Color(1, 1, 1, 0.6)
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		browse_list.add_child(empty_lbl)
	for l in others:
		browse_list.add_child(_make_browse_row(l))

const ItemTooltipRowScript := preload("res://scripts/ItemTooltipRow.gd")

func _icon_box(item: Dictionary, size_px: float = 44.0) -> Control:
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var box := PanelContainer.new()
	box.set_script(ItemTooltipRowScript)
	box.set_item(item)
	box.custom_minimum_size = Vector2(size_px, size_px)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18)
	sb.set_corner_radius_all(4)
	box.add_theme_stylebox_override("panel", sb)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = rarity_color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(size_px - 8.0, size_px - 8.0)
	box.add_child(icon)
	return box

func _make_list_row(stash_index: int) -> Control:
	var item: Dictionary = GameManager.stash_items[stash_index]
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var range_v: Vector2i = GameManager.get_flea_market_price_range(item)

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 54)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.09, 0.85)
	sb.border_color = rarity_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	hbox.add_child(_icon_box(item, 40.0))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_lbl.clip_text = true
	info.add_child(name_lbl)
	var sub_lbl := Label.new()
	sub_lbl.text = "%s  ·  suggested %d-%d" % [GameManager.get_rarity_label(rarity), range_v.x, range_v.y]
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.modulate = Color(1, 1, 1, 0.6)
	info.add_child(sub_lbl)
	hbox.add_child(info)

	var price_edit := LineEdit.new()
	price_edit.text = str(int((range_v.x + range_v.y) / 2.0))
	price_edit.custom_minimum_size = Vector2(64, 32)
	price_edit.add_theme_font_size_override("font_size", 12)
	hbox.add_child(price_edit)
	_price_edits[stash_index] = price_edit

	var list_btn := Button.new()
	list_btn.text = "List"
	list_btn.custom_minimum_size = Vector2(60, 32)
	list_btn.add_theme_font_size_override("font_size", 12)
	list_btn.pressed.connect(func():
		var price: int = int(price_edit.text) if price_edit.text.is_valid_int() else 0
		if GameManager.list_item_on_flea_market(stash_index, price):
			refresh()
	)
	hbox.add_child(list_btn)

	return row

func _time_left_text(target_unix: float) -> String:
	var secs: int = int(target_unix - Time.get_unix_time_from_system())
	if secs <= 0:
		return "any moment now"
	if secs < 60:
		return "%ds" % secs
	if secs < 3600:
		return "%dm" % int(secs / 60.0)
	return "%dh %dm" % [int(secs / 3600.0), int(secs / 60.0) % 60]

# A real ticking HH:MM countdown for your own listings, instead of a
# "will sell in ~X" guess - reads like an actual marketplace listing
# timer counting down to expiry.
func _countdown_text(target_unix: float) -> String:
	var secs: int = max(0, int(target_unix - Time.get_unix_time_from_system()))
	var hours: int = int(secs / 3600.0)
	var mins: int = int(secs / 60.0) % 60
	return "%02d:%02d" % [hours, mins]

func _make_mine_row(listing: Dictionary) -> Control:
	var item: Dictionary = listing.get("item", {})
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 54)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.12, 0.9)
	sb.border_color = rarity_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	hbox.add_child(_icon_box(item, 40.0))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_lbl := Label.new()
	name_lbl.text = "%s  -  %d Rubles" % [str(item.get("name", "?")), int(listing.get("price", 0))]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_lbl.clip_text = true
	info.add_child(name_lbl)
	var sub_lbl := Label.new()
	sub_lbl.text = "Expires in %s" % _countdown_text(float(listing.get("expire_at", 0.0)))
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.modulate = Color(1, 1, 1, 0.6)
	info.add_child(sub_lbl)
	_mine_countdowns.append({"expire_at": float(listing.get("expire_at", 0.0)), "label": sub_lbl})
	hbox.add_child(info)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(70, 32)
	cancel_btn.add_theme_font_size_override("font_size", 12)
	var listing_id: int = int(listing.get("id", -1))
	cancel_btn.pressed.connect(func():
		if GameManager.cancel_flea_listing(listing_id):
			refresh()
	)
	hbox.add_child(cancel_btn)

	return row

func _make_browse_row(listing: Dictionary) -> Control:
	var item: Dictionary = listing.get("item", {})
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var price: int = int(listing.get("price", 0))

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 54)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.1, 0.85)
	sb.border_color = rarity_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	hbox.add_child(_icon_box(item, 40.0))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_lbl := Label.new()
	name_lbl.text = str(item.get("name", "?"))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_lbl.clip_text = true
	info.add_child(name_lbl)
	var sub_lbl := Label.new()
	sub_lbl.text = "%s  ·  sold by %s" % [GameManager.get_rarity_label(rarity), str(listing.get("seller_name", "?"))]
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.modulate = Color(1, 1, 1, 0.6)
	info.add_child(sub_lbl)
	hbox.add_child(info)

	var buy_btn := Button.new()
	buy_btn.text = "Buy\n%d R" % price
	buy_btn.custom_minimum_size = Vector2(64, 36)
	buy_btn.add_theme_font_size_override("font_size", 11)
	buy_btn.disabled = GameManager.rubles < price
	var listing_id: int = int(listing.get("id", -1))
	buy_btn.pressed.connect(func():
		if GameManager.buy_flea_listing(listing_id):
			refresh()
	)
	hbox.add_child(buy_btn)

	return row
