extends Panel

# Guild Battle Pass tier list - same shape as MilestonesPanel.gd (full
# progress bar + claimed/next/locked tier rows), themed to the Guild
# panel's lavender accent and fed by GameManager.guild_battle_pass_tier/
# GUILD_BATTLE_PASS_TIER_DATA instead of the Milestones track.

signal closed

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const ACCENT := Color(0.85, 0.65, 1.0, 1)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var honor_label: Label = $VBox/TopRow/HonorLabel
@onready var tier_label: Label = $VBox/TierRow/TierLabel
@onready var progress_bar: ProgressBar = $VBox/TierRow/ProgressBar
@onready var tier_list: VBoxContainer = $VBox/TierScroll/TierList
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	refresh()

func refresh() -> void:
	honor_label.text = "Lifetime Honor Earned: %d" % GameManager.guild_honor
	tier_label.text = "Tier %d / %d" % [GameManager.guild_battle_pass_tier, GameManager.GUILD_BATTLE_PASS_MAX_TIER]
	progress_bar.max_value = GameManager.GUILD_HONOR_PER_TIER
	progress_bar.value = GameManager.guild_battle_pass_progress

	for c in tier_list.get_children():
		c.queue_free()
	var tiers: Array = GameManager.GUILD_BATTLE_PASS_TIER_DATA
	for i in range(tiers.size()):
		tier_list.add_child(_make_tier_row(i + 1, tiers[i]))

func _make_tier_row(tier: int, reward: Dictionary) -> Control:
	var claimed: bool = tier <= GameManager.guild_battle_pass_tier
	var is_next: bool = tier == GameManager.guild_battle_pass_tier + 1

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 64)
	var sb := StyleBoxFlat.new()
	if claimed:
		sb.bg_color = Color(0.16, 0.12, 0.2, 0.9)
		sb.border_color = ACCENT
	elif is_next:
		sb.bg_color = Color(0.13, 0.1, 0.16, 0.9)
		sb.border_color = Color(0.75, 0.55, 0.95, 0.9)
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

	var icon_slot := Control.new()
	icon_slot.custom_minimum_size = Vector2(40, 40)
	hbox.add_child(icon_slot)
	_populate_reward_icon(icon_slot, reward)

	var name_vbox := VBoxContainer.new()
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_vbox)

	var name_lbl := Label.new()
	name_lbl.text = str(reward.get("name", "Tier %d" % tier))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", ACCENT)
	name_vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = _reward_text(reward)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.modulate = Color(1, 1, 1, 0.75)
	name_vbox.add_child(desc_lbl)

	var completion_lbl := Label.new()
	completion_lbl.text = _completion_text(tier, claimed, is_next)
	completion_lbl.add_theme_font_size_override("font_size", 11)
	completion_lbl.modulate = Color(0.85, 0.8, 0.9, 0.7)
	name_vbox.add_child(completion_lbl)

	var status_lbl := Label.new()
	status_lbl.custom_minimum_size = Vector2(90, 0)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_size_override("font_size", 13)
	if claimed:
		status_lbl.text = "Claimed"
		status_lbl.add_theme_color_override("font_color", ACCENT)
	elif is_next:
		status_lbl.text = "Next Up"
		status_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0, 1))
	else:
		status_lbl.text = "Locked"
		status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	hbox.add_child(status_lbl)

	return row

func _populate_reward_icon(slot: Control, reward: Dictionary) -> void:
	match reward.get("type", ""):
		"lootbag":
			var icon = ItemIconScene.instantiate()
			icon.icon_key = "lootbag"
			icon.icon_color = GameManager.get_lootbag_color(str(reward.get("bag_tier", "rare")))
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
		"skill_points":
			var amt := int(reward.get("amount", 0))
			return "%d Skill Point%s" % [amt, "" if amt == 1 else "s"]
		"lootbag":
			return "%s Loot Bag" % String(reward.get("bag_tier", "rare")).capitalize()
		_:
			return "?"

func _completion_text(tier: int, claimed: bool, is_next: bool) -> String:
	if claimed:
		return "Completed"
	if is_next:
		return "%d / %d Honor" % [GameManager.guild_battle_pass_progress, GameManager.GUILD_HONOR_PER_TIER]
	return "Locked until Tier %d is claimed (%d Honor each)" % [tier - 1, GameManager.GUILD_HONOR_PER_TIER]
