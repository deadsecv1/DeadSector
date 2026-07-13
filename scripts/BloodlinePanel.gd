extends Panel

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()
signal enter_gauntlet_requested

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const PulsingButtonFXScript := preload("res://scripts/PulsingButtonFX.gd")

@onready var tier_label: Label = $VBox/TierLabel
@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var shards_label: Label = $VBox/ShardsLabel
@onready var reward_row: HBoxContainer = $VBox/RewardScroll/RewardRow
@onready var skip_button: Button = $VBox/SkipButton
@onready var gauntlet_button: Button = $VBox/GauntletButton
@onready var level_label: Label = $VBox/LevelLabel
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	# Full-screen panel (fills the whole viewport) - no draggable edges here, unlike the smaller centered popups.
	close_button.pressed.connect(func(): closed.emit())
	PulsingButtonFXScript.apply(gauntlet_button, Color(1.0, 0.15, 0.15, 1))
	skip_button.pressed.connect(_on_skip)
	gauntlet_button.pressed.connect(func(): enter_gauntlet_requested.emit())

func open() -> void:
	visible = true
	refresh()

func refresh() -> void:
	var tier: int = GameManager.bloodline_tier
	var max_tier: int = GameManager.BLOODLINE_MAX_TIER
	tier_label.text = "BLOODLINE - Tier %d / %d" % [tier, max_tier]
	shards_label.text = "Blood Shards: %d" % GameManager.blood_shards

	if tier >= max_tier:
		progress_bar.value = 1.0
		progress_label.text = "MAX TIER"
		skip_button.disabled = true
	else:
		var needed := 100 + tier * 20
		progress_bar.max_value = float(needed)
		progress_bar.value = float(GameManager.bloodline_progress)
		progress_label.text = "%d / %d Blood Shards to next tier" % [GameManager.bloodline_progress, needed]
		skip_button.disabled = GameManager.blood_shards < 50
	skip_button.text = "Skip Tier (50 Blood Shards)"

	level_label.text = "Gauntlet progress: Level %d / %d cleared" % [GameManager.gauntlet_best_level, GameManager.GAUNTLET_MAX_LEVEL]

	for c in reward_row.get_children():
		reward_row.remove_child(c)
		c.queue_free()
	var rewards := GameManager._generate_bloodline_rewards()
	var start: int = max(0, tier)
	for i in range(start, rewards.size()):
		reward_row.add_child(_make_reward_slot(rewards[i], i + 1))

func _make_reward_slot(reward: Dictionary, tier_num: int) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(70, 90)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.03, 0.04, 0.9)
	sb.border_color = Color(0.7, 0.1, 0.12, 1)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	slot.add_child(vbox)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d" % tier_num
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 10)
	tier_lbl.modulate = Color(1, 1, 1, 0.6)
	vbox.add_child(tier_lbl)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(0, 44)
	match reward.get("type", ""):
		"item":
			var data: Dictionary = reward.get("data", {})
			var icon = ItemIconScene.instantiate()
			icon.icon_key = data.get("icon_key", "generic")
			icon.icon_color = GameManager.get_rarity_color(data.get("rarity", "legendary"))
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			icon_box.add_child(icon)
		"pet":
			var icon = ItemIconScene.instantiate()
			icon.icon_key = "pet_crow"
			icon.icon_color = Color(0.6, 0.1, 0.12, 1)
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			icon_box.add_child(icon)
		_:
			var lbl := Label.new()
			lbl.text = "+%d" % int(reward.get("amount", 0))
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.anchor_right = 1.0
			lbl.anchor_bottom = 1.0
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4, 1))
			icon_box.add_child(lbl)
	vbox.add_child(icon_box)

	return slot

func _on_skip() -> void:
	if GameManager.skip_bloodline_tier():
		refresh()
	else:
		GameManager.toast_requested.emit("Not enough Blood Shards to skip a tier")
