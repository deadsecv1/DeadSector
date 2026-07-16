extends Panel

# The Guild Hall statue's popup - a rotating weekly guild-wide objective
# (see GameManager's GUILD_CONTRACT_TYPES/get_current_guild_contract()).
# Built entirely in code like PlayerContextMenu's profile popup, since
# it's a small, self-contained card rather than a full-screen scrollable
# panel like Milestones/Battle Pass.

signal closed

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

@onready var title_label: Label = $VBox/TitleLabel
@onready var desc_label: Label = $VBox/DescLabel
@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var timer_label: Label = $VBox/TimerLabel
@onready var tier_list: VBoxContainer = $VBox/TierList
@onready var close_button: Button = $VBox/CloseButton

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

func _ready() -> void:
	visible = false
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -190
	offset_top = -220
	offset_right = 190
	offset_bottom = 220
	refresh()
	GameManager.focus_first_control(self)

func refresh() -> void:
	var contract: Dictionary = GameManager.get_current_guild_contract()
	title_label.text = str(contract.get("title", "Guild Contract"))
	desc_label.text = str(contract.get("desc", ""))
	var progress: int = GameManager.get_guild_contract_progress()
	var target: int = int(contract.get("target", 1))
	progress_bar.max_value = target
	progress_bar.value = progress
	progress_label.text = "%d / %d" % [progress, target]

	var seconds_left: int = GameManager.get_guild_contract_seconds_remaining()
	var days_left: int = seconds_left / 86400
	var hours_left: int = (seconds_left % 86400) / 3600
	timer_label.text = "New contract in %dd %dh" % [days_left, hours_left]

	for c in tier_list.get_children():
		c.queue_free()
	for i in range(GameManager.GUILD_CONTRACT_TIER_FRACTIONS.size()):
		tier_list.add_child(_make_tier_row(i))

func _make_tier_row(tier_index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var tier_target: int = GameManager.get_guild_contract_tier_target(tier_index)
	var reward: Dictionary = GameManager.GUILD_CONTRACT_TIER_REWARDS[tier_index]
	var reward_bits: Array = []
	if reward.get("rubles", 0) > 0:
		reward_bits.append("%d Rubles" % int(reward["rubles"]))
	if reward.get("artifacts", 0) > 0:
		reward_bits.append("%d Artifacts" % int(reward["artifacts"]))
	if reward.get("guild_honor", 0) > 0:
		reward_bits.append("%d Honor" % int(reward["guild_honor"]))

	var label := Label.new()
	label.text = "At %d: %s" % [tier_target, ", ".join(reward_bits)]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	var claimed: bool = GameManager.is_guild_contract_tier_claimed(tier_index)
	var reached: bool = GameManager.get_guild_contract_progress() >= tier_target
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 32)
	if claimed:
		btn.text = "Claimed"
		btn.disabled = true
	elif reached:
		btn.text = "Claim"
		btn.pressed.connect(func():
			if GameManager.claim_guild_contract_tier(tier_index):
				refresh()
				GameManager.focus_first_control(self)
		)
	else:
		btn.text = "Locked"
		btn.disabled = true
	row.add_child(btn)
	return row
