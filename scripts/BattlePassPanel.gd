extends Panel

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")
const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const PulsingButtonFXScript := preload("res://scripts/PulsingButtonFX.gd")

@onready var souls_label: Label = $VBox/TopRow/SoulsLabel
@onready var tier_label: Label = $VBox/TierRow/TierLabel
@onready var progress_bar: ProgressBar = $VBox/TierRow/ProgressBar
@onready var skip_button: Button = $VBox/ButtonRow/SkipButton
@onready var skip_souls_button: Button = $VBox/ButtonRow/SkipSoulsButton
@onready var commune_button: Button = $VBox/ButtonRow/CommuneButton
@onready var tier_list: VBoxContainer = $VBox/ListScroll/TierList
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	# Full-screen panel (fills the whole viewport) - no draggable edges here, unlike the smaller centered popups.
	close_button.pressed.connect(func(): closed.emit())
	skip_button.pressed.connect(_on_skip)
	skip_souls_button.pressed.connect(_on_skip_souls)
	commune_button.pressed.connect(_on_commune)
	PulsingButtonFXScript.apply(commune_button, Color(0.6, 0.95, 0.85, 1))

func open() -> void:
	visible = true
	refresh()

func refresh() -> void:
	souls_label.text = "Souls: %d" % GameManager.souls
	tier_label.text = "Tier %d / %d" % [GameManager.battle_pass_tier, GameManager.BATTLE_PASS_MAX_TIER]
	progress_bar.max_value = GameManager.BATTLE_PASS_XP_PER_TIER
	progress_bar.value = GameManager.battle_pass_progress
	skip_button.text = "Skip Tier (5,000 Rubles)"
	skip_button.disabled = GameManager.battle_pass_tier >= GameManager.BATTLE_PASS_MAX_TIER or GameManager.rubles < 5000
	skip_souls_button.text = "Skip Tier (%d Souls)" % GameManager.SOULS_PER_TIER_SKIP
	skip_souls_button.disabled = GameManager.battle_pass_tier >= GameManager.BATTLE_PASS_MAX_TIER or GameManager.souls < GameManager.SOULS_PER_TIER_SKIP

	for c in tier_list.get_children():
		c.queue_free()
	var rewards: Array = GameManager._generate_battle_pass_rewards()
	for i in range(rewards.size()):
		tier_list.add_child(_make_tier_row(i + 1, rewards[i]))

func _make_tier_row(tier: int, reward: Dictionary) -> Control:
	var claimed: bool = tier <= GameManager.battle_pass_tier
	var is_next: bool = tier == GameManager.battle_pass_tier + 1

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 64)
	var sb := StyleBoxFlat.new()
	if claimed:
		sb.bg_color = Color(0.1, 0.22, 0.18, 0.9)
		sb.border_color = Color(0.4, 0.9, 0.7, 0.8)
	elif is_next:
		sb.bg_color = Color(0.14, 0.16, 0.1, 0.9)
		sb.border_color = Color(0.85, 0.75, 0.3, 0.9)
	else:
		sb.bg_color = Color(0.08, 0.09, 0.09, 0.75)
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
	tier_lbl.custom_minimum_size = Vector2(70, 0)
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
		desc_lbl.add_theme_color_override("font_color", GameManager.get_rarity_color(reward.get("data", {}).get("rarity", "epic")))
	hbox.add_child(desc_lbl)

	var status_lbl := Label.new()
	status_lbl.custom_minimum_size = Vector2(90, 0)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_size_override("font_size", 13)
	if claimed:
		status_lbl.text = "Claimed"
		status_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.7, 1))
	elif is_next:
		status_lbl.text = "Next Up"
		status_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4, 1))
	else:
		status_lbl.text = "Locked"
		status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	hbox.add_child(status_lbl)

	return row

func _populate_reward_icon(slot: Control, reward: Dictionary) -> void:
	match reward.get("type", ""):
		"item":
			var item_rarity: String = reward.get("data", {}).get("rarity", "epic")
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
		_:
			var icon = SmallIconScene.instantiate()
			icon.icon_type = "money"
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			slot.add_child(icon)

func _reward_text(reward: Dictionary) -> String:
	match reward.get("type", ""):
		"souls":
			return "%d Souls" % int(reward.get("amount", 0))
		"rubles":
			return "%d Rubles" % int(reward.get("amount", 0))
		"xp":
			return "%d XP" % int(reward.get("amount", 0))
		"skill_points":
			var amt := int(reward.get("amount", 0))
			return "%d Skill Point%s" % [amt, "" if amt == 1 else "s"]
		"item":
			var d: Dictionary = reward.get("data", {})
			return "%s (%s)" % [d.get("name", "?"), String(d.get("rarity", "epic")).capitalize()]
		"lootbag":
			return "Loot Bag"
		_:
			return "?"

func _on_skip() -> void:
	if GameManager.skip_battle_pass_tier():
		refresh()
	else:
		GameManager.toast_requested.emit("Not enough Rubles to skip a tier")

func _on_skip_souls() -> void:
	if GameManager.skip_battle_pass_tier_with_souls():
		refresh()
	else:
		GameManager.toast_requested.emit("Not enough Souls to skip a tier")

func _on_commune() -> void:
	Transition.change_scene("res://scenes/SoulRealm.tscn")
