extends Panel

# "Pre Season Pass" tier list - same tier-row/reward-icon shape as
# BattlePassPanel.gd (rewards generated deterministically from a fixed
# seed rather than stored), re-themed and with two real differences:
# progress comes from GameManager.stat_extractions (not a granted-XP
# currency, so there's no manual "claim" - see _sync_season_pass_tier())
# and the panel shows a real countdown to GameManager.SEASON_PASS_END_TIMESTAMP.

signal closed

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const ACCENT := Color(1.0, 0.75, 0.3, 1)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var countdown_label: Label = $VBox/TopRow/CountdownLabel
@onready var extractions_label: Label = $VBox/TopRow/ExtractionsLabel
@onready var tier_label: Label = $VBox/TierRow/TierLabel
@onready var progress_bar: ProgressBar = $VBox/TierRow/ProgressBar
@onready var skip_button: Button = $VBox/ButtonRow/SkipButton
@onready var tier_list: VBoxContainer = $VBox/ListScroll/TierList
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): closed.emit())
	skip_button.pressed.connect(_on_skip)

func open() -> void:
	visible = true
	refresh()
	GameManager.focus_first_control(self)
	PanelOpenFX.animate_open(self)

func _process(_delta: float) -> void:
	if visible:
		_update_countdown()

func _update_countdown() -> void:
	if not GameManager.season_pass_available():
		countdown_label.text = "The Pre Season Pass has ended."
		countdown_label.add_theme_color_override("font_color", Color(1, 0.4, 0.35, 1))
		return
	var secs := int(GameManager.season_pass_seconds_left())
	var days := int(secs / 86400.0)
	var hours := int(secs / 3600.0) % 24
	var mins := int(secs / 60.0) % 60
	if days > 0:
		countdown_label.text = "Ends in %d days, %d hours" % [days, hours]
	else:
		countdown_label.text = "Ends in %d hours, %d minutes - don't miss it!" % [hours, mins]
	countdown_label.add_theme_color_override("font_color", Color(1, 0.4, 0.35, 1) if days == 0 else Color(1, 0.85, 0.6, 1))

func refresh() -> void:
	_update_countdown()
	extractions_label.text = "Extractions: %d" % GameManager.stat_extractions
	tier_label.text = "Tier %d / %d" % [GameManager.season_pass_tier, GameManager.SEASON_PASS_MAX_TIER]
	var into_tier: int = GameManager.stat_extractions % GameManager.SEASON_PASS_EXTRACTIONS_PER_TIER
	progress_bar.max_value = GameManager.SEASON_PASS_EXTRACTIONS_PER_TIER
	progress_bar.value = 0 if GameManager.season_pass_tier >= GameManager.SEASON_PASS_MAX_TIER else into_tier
	skip_button.text = "Skip Tier (3,000 Rubles)"
	skip_button.disabled = not GameManager.season_pass_available() or GameManager.season_pass_tier >= GameManager.SEASON_PASS_MAX_TIER or GameManager.rubles < 3000

	for c in tier_list.get_children():
		c.queue_free()
	var rewards: Array = GameManager._generate_season_pass_rewards()
	for i in range(rewards.size()):
		tier_list.add_child(_make_tier_row(i + 1, rewards[i]))

func _make_tier_row(tier: int, reward: Dictionary) -> Control:
	var claimed: bool = tier <= GameManager.season_pass_tier
	var is_next: bool = tier == GameManager.season_pass_tier + 1

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 64)
	var sb := StyleBoxFlat.new()
	if claimed:
		sb.bg_color = Color(0.2, 0.15, 0.06, 0.9)
		sb.border_color = ACCENT
	elif is_next:
		sb.bg_color = Color(0.16, 0.13, 0.08, 0.9)
		sb.border_color = Color(0.95, 0.85, 0.5, 0.9)
	else:
		sb.bg_color = Color(0.08, 0.08, 0.09, 0.75)
		sb.border_color = Color(1, 1, 1, 0.15)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var tier_lbl := Label.new()
	tier_lbl.text = "Tier %d" % tier
	tier_lbl.custom_minimum_size = Vector2(60, 0)
	tier_lbl.add_theme_font_size_override("font_size", 14)
	hbox.add_child(tier_lbl)

	var icon_slot := Control.new()
	icon_slot.custom_minimum_size = Vector2(40, 40)
	hbox.add_child(icon_slot)
	_populate_reward_icon(icon_slot, reward)

	var desc_lbl := Label.new()
	desc_lbl.text = _reward_text(reward)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 14)
	if reward.get("type", "") == "item":
		desc_lbl.add_theme_color_override("font_color", GameManager.get_rarity_color(reward.get("data", {}).get("rarity", "rare")))
	hbox.add_child(desc_lbl)

	var status_lbl := Label.new()
	status_lbl.custom_minimum_size = Vector2(90, 0)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_size_override("font_size", 13)
	if claimed:
		status_lbl.text = "Claimed"
		status_lbl.add_theme_color_override("font_color", ACCENT)
	elif is_next:
		status_lbl.text = "Next Up"
		status_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1))
	else:
		status_lbl.text = "Locked"
		status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	hbox.add_child(status_lbl)

	return row

func _populate_reward_icon(slot: Control, reward: Dictionary) -> void:
	match reward.get("type", ""):
		"item":
			var item_rarity: String = reward.get("data", {}).get("rarity", "rare")
			var icon = ItemIconScene.instantiate()
			icon.icon_key = reward.get("data", {}).get("icon_key", "generic")
			icon.icon_color = GameManager.get_rarity_color(item_rarity)
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			icon.offset_left = 3
			icon.offset_top = 3
			icon.offset_right = -3
			icon.offset_bottom = -3
			slot.add_child(icon)
			var gradient_border = GameManager.make_gradient_border(item_rarity)
			if gradient_border != null:
				slot.add_child(gradient_border)
				slot.move_child(gradient_border, 0)
				var slot_bg := ColorRect.new()
				slot_bg.color = Color(0.08, 0.08, 0.08, 0.92)
				slot_bg.anchor_right = 1.0
				slot_bg.anchor_bottom = 1.0
				slot_bg.offset_left = 3
				slot_bg.offset_top = 3
				slot_bg.offset_right = -3
				slot_bg.offset_bottom = -3
				slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
				slot.add_child(slot_bg)
				slot.move_child(slot_bg, 1)
		"lootbag":
			var icon = ItemIconScene.instantiate()
			icon.icon_key = "lootbag"
			icon.icon_color = GameManager.get_rarity_color("epic")
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			slot.add_child(icon)
		"xp":
			var icon = SmallIconScene.instantiate()
			icon.icon_type = "tech"
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			slot.add_child(icon)
		"skill_points":
			var icon = ItemIconScene.instantiate()
			icon.icon_key = "skill_points_item"
			icon.icon_color = Color(0.55, 0.78, 1.0, 1)
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			slot.add_child(icon)
		"artifacts":
			var icon = ItemIconScene.instantiate()
			icon.icon_key = "artifacts_item"
			icon.icon_color = Color(0.7, 0.6, 0.85, 1)
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			slot.add_child(icon)
		_:
			var icon = SmallIconScene.instantiate()
			icon.icon_type = "money"
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			slot.add_child(icon)

func _reward_text(reward: Dictionary) -> String:
	match reward.get("type", ""):
		"rubles":
			return "%d Rubles" % int(reward.get("amount", 0))
		"xp":
			return "%d XP" % int(reward.get("amount", 0))
		"artifacts":
			return "%d Artifacts" % int(reward.get("amount", 0))
		"skill_points":
			var amt := int(reward.get("amount", 0))
			return "%d Skill Point%s" % [amt, "" if amt == 1 else "s"]
		"item":
			var d: Dictionary = reward.get("data", {})
			return "%s (%s)" % [d.get("name", "?"), String(d.get("rarity", "rare")).capitalize()]
		"lootbag":
			return "Loot Bag"
		_:
			return "?"

func _on_skip() -> void:
	if GameManager.skip_season_pass_tier():
		refresh()
	else:
		GameManager.toast_requested.emit("Not enough Rubles to skip a tier")
