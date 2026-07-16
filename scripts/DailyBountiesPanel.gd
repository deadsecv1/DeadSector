extends Panel

# 3 small daily objectives, rerolled at a fixed real-calendar-day
# boundary (see GameManager's DAILY_BOUNTY_TYPES/_ensure_daily_bounties_
# current()). Same small self-contained-card approach as
# GuildContractPanel.gd, just one card per active slot instead of one
# card's worth of tiers.

signal closed

@onready var timer_label: Label = $VBox/TimerLabel
@onready var slot_list: VBoxContainer = $VBox/SlotList
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
	offset_top = -230
	offset_right = 190
	offset_bottom = 230
	refresh()
	GameManager.focus_first_control(self)
	PanelOpenFX.animate_open(self)

func refresh() -> void:
	var seconds_left: int = 86400 - (int(Time.get_unix_time_from_system()) % 86400)
	var hours_left: int = seconds_left / 3600
	var minutes_left: int = (seconds_left % 3600) / 60
	timer_label.text = "New bounties in %dh %dm" % [hours_left, minutes_left]

	for c in slot_list.get_children():
		c.queue_free()
	var slots: Array = GameManager.get_daily_bounty_slots()
	for i in range(slots.size()):
		slot_list.add_child(_make_slot_card(i))

func _make_slot_card(slot_index: int) -> Control:
	var bounty_type: Dictionary = GameManager.get_daily_bounty_type(slot_index)
	var progress: int = GameManager.get_daily_bounty_progress(slot_index)
	var target: int = int(bounty_type.get("target", 1))
	var claimed: bool = GameManager.is_daily_bounty_claimed(slot_index)
	var reached: bool = GameManager.is_daily_bounty_complete(slot_index)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.14, 0.16, 0.95)
	sb.border_color = Color(0.9, 0.8, 0.5, 0.7) if claimed else Color(1, 1, 1, 0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	var title_lbl := Label.new()
	title_lbl.text = str(bounty_type.get("title", "Bounty"))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5, 1))
	title_row.add_child(title_lbl)
	var progress_lbl := Label.new()
	progress_lbl.text = "%d / %d" % [min(progress, target), target]
	progress_lbl.add_theme_font_size_override("font_size", 12)
	title_row.add_child(progress_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(bounty_type.get("desc", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.modulate = Color(1, 1, 1, 0.75)
	vbox.add_child(desc_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	bar.max_value = target
	bar.value = progress
	vbox.add_child(bar)

	var claim_btn := Button.new()
	claim_btn.custom_minimum_size = Vector2(0, 30)
	if claimed:
		claim_btn.text = "Claimed"
		claim_btn.disabled = true
	elif reached:
		claim_btn.text = "Claim: %d Rubles, %d Skill Points" % [int(GameManager.DAILY_BOUNTY_REWARD["rubles"]), int(GameManager.DAILY_BOUNTY_REWARD["skill_points"])]
		claim_btn.pressed.connect(func():
			if GameManager.claim_daily_bounty(slot_index):
				refresh()
		)
	else:
		claim_btn.text = "In Progress"
		claim_btn.disabled = true
	vbox.add_child(claim_btn)

	return card
