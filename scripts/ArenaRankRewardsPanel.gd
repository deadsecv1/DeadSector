extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

# Arena's real Rewards screen - what each Arena Rank tier actually
# grants (GameManager.ARENA_REWARD_TIERS), as opposed to ArenaRewardsPanel.gd
# (now the "Ranks" button), which is purely descriptive flavor text per
# tier. Modeled directly on LeaderboardRewardsPanel.gd's tier-card layout.

signal closed

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const TooltipParticlesScript := preload("res://scripts/TooltipParticles.gd")
const ItemTooltipHostScript := preload("res://scripts/ItemTooltipHost.gd")

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var tier_list: VBoxContainer = $VBox/TierScroll/TierList
@onready var close_button: Button = $VBox/CloseButton
@onready var sparkles_holder: Control = $Sparkles

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

	var sparkles := Control.new()
	sparkles.anchor_right = 1.0
	sparkles.anchor_bottom = 1.0
	sparkles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkles.set_script(TooltipParticlesScript)
	sparkles.particle_color = Color(0.75, 0.55, 0.95, 1)
	sparkles.intensity = 34
	sparkles_holder.add_child(sparkles)

	_build_tiers()

func open() -> void:
	visible = true
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -340.0
	offset_top = -300.0
	offset_right = 340.0
	offset_bottom = 300.0
	_build_tiers()
	GameManager.focus_first_control(self)

func _build_tiers() -> void:
	for c in tier_list.get_children():
		c.queue_free()
	var reward_tiers: Array = GameManager.ARENA_REWARD_TIERS
	for i in range(reward_tiers.size()):
		tier_list.add_child(_make_tier_card(reward_tiers[i], i))

func _make_tier_card(tier: Dictionary, index: int) -> Control:
	var rank_tier: Dictionary = GameManager.get_arena_rank_tier(index)
	var rank_color: Color = rank_tier.get("color", Color.WHITE)
	var is_current: bool = GameManager.get_arena_rank_index() == index

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.08, 0.13, 0.9)
	sb.border_color = rank_color if is_current else Color(rank_color.r, rank_color.g, rank_color.b, 0.5)
	sb.set_border_width_all(3 if is_current else 1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var tier_lbl := Label.new()
	tier_lbl.text = str(tier.get("label", "?")) + (" (Your Rank)" if is_current else "")
	tier_lbl.add_theme_font_size_override("font_size", 20)
	tier_lbl.add_theme_color_override("font_color", rank_color)
	header.add_child(tier_lbl)

	var badge_id: String = str(tier.get("badge", ""))
	if badge_id != "":
		var bdata: Dictionary = GameManager.BADGE_CATALOG.get(badge_id, {})
		var badge_icon = SmallIconScene.instantiate()
		badge_icon.icon_type = bdata.get("icon", "star")
		badge_icon.icon_bg = bdata.get("color", Color.WHITE) * 0.3
		badge_icon.custom_minimum_size = Vector2(26, 26)
		badge_icon.tooltip_text = str(bdata.get("name", badge_id))
		header.add_child(badge_icon)
		var badge_lbl := Label.new()
		badge_lbl.text = str(bdata.get("name", badge_id))
		badge_lbl.add_theme_font_size_override("font_size", 12)
		badge_lbl.add_theme_color_override("font_color", bdata.get("color", Color.WHITE))
		badge_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		header.add_child(badge_lbl)

	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", 8)
	vbox.add_child(reward_row)

	reward_row.add_child(_make_reward_chip("rubles_item", "%s Rubles" % _format_num(int(tier.get("rubles", 0))), Color(0.85, 0.75, 0.35, 1)))
	if int(tier.get("artifacts", 0)) > 0:
		reward_row.add_child(_make_reward_chip("artifacts_item", "%d Artifacts" % int(tier.get("artifacts", 0)), Color(0.7, 0.6, 0.85, 1)))
	if int(tier.get("alloys", 0)) > 0:
		reward_row.add_child(_make_reward_chip("alloys_item", "%d Alloys" % int(tier.get("alloys", 0)), Color(0.6, 0.8, 0.6, 1)))
	if int(tier.get("skill_points", 0)) > 0:
		reward_row.add_child(_make_reward_chip("skill_points_item", "%d Skill Points" % int(tier.get("skill_points", 0)), Color(0.55, 0.78, 1.0, 1)))

	var bags: Array = tier.get("bags", [])
	if not bags.is_empty():
		var bag_row := HBoxContainer.new()
		bag_row.add_theme_constant_override("separation", 8)
		vbox.add_child(bag_row)
		for bag_tier in bags:
			var bag_data: Dictionary = GameManager.LOOT_BAG_TIERS.get(bag_tier, {})
			var bag_item: Dictionary = bag_data.duplicate(true)
			bag_item["icon_key"] = "lootbag"
			bag_row.add_child(_make_reward_chip("lootbag", str(bag_data.get("name", "Loot Bag")), GameManager.get_lootbag_color(str(bag_data.get("rarity", "common"))), bag_item))

	return card

func _make_reward_chip(icon_key: String, label_text: String, color: Color, item_data: Dictionary = {}) -> Control:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.05, 0.85)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", sb)
	if not item_data.is_empty():
		chip.set_script(ItemTooltipHostScript)
		chip.item = item_data
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		chip.tooltip_text = label_text

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	chip.add_child(hbox)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(20, 20)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = icon_key
	icon.icon_color = color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	return chip

func _format_num(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i != 0:
			out = "," + out
	return out
