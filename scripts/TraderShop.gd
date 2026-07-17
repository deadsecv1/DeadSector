extends Control

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const CURRENCY_LABELS := {"rubles": "Rubles", "junk": "Junk", "artifacts": "Artifacts", "alloys": "Alloys"}

@onready var title_label: Label = $VBox/TitleLabel
@onready var tagline_label: Label = $VBox/TaglineLabel
@onready var coins_label: Label = $VBox/CoinsLabel
@onready var rotation_label: Label = $VBox/RotationLabel
@onready var buy_list: VBoxContainer = $VBox/Panels/BuyPanel/BuyVBox/BuyScroll/BuyList
@onready var sell_list: VBoxContainer = $VBox/Panels/SellPanel/SellVBox/SellScroll/SellList
@onready var back_button: Button = $VBox/BackButton
@onready var deliver_button: Button = $VBox/DeliverButton

var trader_id: String = "medic"
const ROTATING_TRADERS := ["medic", "quartermaster", "scavenger"]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()

func _ready() -> void:
	trader_id = GameManager.current_trader_id
	back_button.pressed.connect(func(): Transition.change_scene_instant("res://scenes/Traders.tscn"))
	deliver_button.pressed.connect(func():
		if GameManager.deliver_batteries():
			refresh()
	)
	GameManager.traders_rotated.connect(refresh)
	refresh()
	GameManager.focus_first_control(self)

func _process(_delta: float) -> void:
	if trader_id in ROTATING_TRADERS:
		rotation_label.visible = true
		var secs := int(GameManager.get_trader_rotation_seconds_left())
		rotation_label.text = "Stock refreshes in %d:%02d" % [int(secs / 60.0), secs % 60]
	else:
		rotation_label.visible = false

func _currency() -> String:
	return GameManager.TRADER_CATALOG.get(trader_id, {}).get("currency", "rubles")

func _currency_label() -> String:
	return CURRENCY_LABELS.get(_currency(), "Rubles")

func refresh() -> void:
	var trader: Dictionary = GameManager.TRADER_CATALOG.get(trader_id, {})
	title_label.text = str(trader.get("name", "Trader"))
	tagline_label.text = str(trader.get("tagline", ""))
	coins_label.text = "Your %s: %d" % [_currency_label(), GameManager.get_currency(_currency())]
	deliver_button.visible = trader_id == "scrapper" and GameManager.quest_status_for("deliver_batteries") == "active"

	for c in buy_list.get_children():
		c.queue_free()
	var items: Array = trader.get("items", [])
	for i in range(items.size()):
		buy_list.add_child(_make_buy_row(items[i], i))

	for c in sell_list.get_children():
		c.queue_free()
	if trader.get("currency", "rubles") != "rubles" and trader_id != "scrapper":
		# Traders who pay out in something other than Rubles (Scrapper is
		# the deliberate exception) don't buy your gear. The Alloy Dealer's
		# own "currency" is "rubles" (that's what he charges for Alloys),
		# so this doesn't exclude him - he does buy gear same as any other
		# rubles trader, that's intentional, not a gap.
		var lbl2 := Label.new()
		lbl2.text = "This trader doesn't buy gear."
		sell_list.add_child(lbl2)
	elif GameManager.stash_items.is_empty():
		var lbl := Label.new()
		lbl.text = "Nothing in your Stash to sell."
		sell_list.add_child(lbl)
	else:
		for i in range(GameManager.stash_items.size()):
			sell_list.add_child(_make_sell_row(GameManager.stash_items[i], i))

func _stat_text(item: Dictionary) -> String:
	if item.has("grants_currency"):
		return "Grants %d %s" % [int(item.get("grants_amount", 0)), CURRENCY_LABELS.get(item["grants_currency"], "?")]
	var stat_type: String = item.get("stat_type", "")
	var stat_value = item.get("stat_value", 0.0)
	match stat_type:
		"speed":
			return "+%s Speed" % stat_value
		"max_health":
			return "+%s Health" % stat_value
		"damage":
			return "+%s Damage" % stat_value
		"fire_rate":
			return "+%s Fire Rate" % stat_value
		_:
			return ""

const ItemTooltipRowScript := preload("res://scripts/ItemTooltipRow.gd")

func _make_item_row(item: Dictionary) -> Dictionary:
	var row := PanelContainer.new()
	row.set_script(ItemTooltipRowScript)
	row.set_item(item)
	row.custom_minimum_size = Vector2(0, 50)

	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = GameManager.get_rarity_color(rarity)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.1, 0.09, 0.85)
	sb.border_color = GameManager.get_gradient_colors(rarity)[0] if GameManager.get_gradient_colors(rarity).size() > 0 else rarity_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var icon_frame := PanelContainer.new()
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.custom_minimum_size = Vector2(36, 36)
	icon_frame.clip_contents = true
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gradient_colors: Array = GameManager.get_gradient_colors(rarity)
	var is_top_tier: bool = gradient_colors.size() > 0
	if not is_top_tier:
		var icon_sb := StyleBoxFlat.new()
		icon_sb.bg_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18)
		icon_sb.set_corner_radius_all(4)
		icon_frame.add_theme_stylebox_override("panel", icon_sb)
	else:
		var gradient_border = GameManager.make_gradient_border(rarity)
		if gradient_border != null:
			icon_frame.add_child(gradient_border)
		var slot_bg := ColorRect.new()
		slot_bg.color = Color(0.09, 0.1, 0.09, 0.9)
		slot_bg.anchor_right = 1.0
		slot_bg.anchor_bottom = 1.0
		slot_bg.offset_left = 2
		slot_bg.offset_top = 2
		slot_bg.offset_right = -2
		slot_bg.offset_bottom = -2
		slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(slot_bg)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = item.get("icon_key", "generic")
	icon.icon_color = rarity_color
	icon.custom_minimum_size = Vector2(30, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon)
	hbox.add_child(icon_frame)

	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	var slot_txt: String = str(item.get("slot", "")).capitalize() if not item.has("grants_currency") else "Currency"
	name_lbl.text = "%s [%s]" % [item.get("name", "?"), slot_txt]
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_lbl.clip_text = true
	info.add_child(name_lbl)
	# Stat and rarity share one compact line instead of two, e.g.
	# "Rare  ·  +20 Speed" - halves the vertical space the old
	# two-separate-labels layout used.
	var sub_lbl := Label.new()
	var stat_txt := _stat_text(item)
	sub_lbl.text = "%s  ·  %s" % [GameManager.get_rarity_label(rarity), stat_txt] if stat_txt != "" else GameManager.get_rarity_label(rarity)
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.add_theme_color_override("font_color", Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.8))
	sub_lbl.clip_text = true
	info.add_child(sub_lbl)
	hbox.add_child(info)

	return {"row": row, "hbox": hbox}

func _make_buy_row(item: Dictionary, index: int) -> Control:
	var built := _make_item_row(item)
	var cost := GameManager.get_discounted_trader_cost(int(item.get("cost", 0)))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(84, 40)
	btn.text = "Buy\n%d %s" % [cost, _currency_label()]
	btn.add_theme_font_size_override("font_size", 11)
	btn.disabled = GameManager.get_currency(_currency()) < cost
	btn.pressed.connect(_on_buy_pressed.bind(index))
	built["hbox"].add_child(btn)
	return built["row"]

func _make_sell_row(item: Dictionary, index: int) -> Control:
	var built := _make_item_row(item)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(84, 40)
	btn.text = "Sell\n%d %s" % [GameManager.get_actual_sell_value(item, _currency()), _currency_label()]
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(_on_sell_pressed.bind(index))
	built["hbox"].add_child(btn)
	return built["row"]

func _on_buy_pressed(index: int) -> void:
	GameManager.buy_trader_item(trader_id, index)
	refresh()

func _on_sell_pressed(index: int) -> void:
	GameManager.sell_item(trader_id, index)
	refresh()
