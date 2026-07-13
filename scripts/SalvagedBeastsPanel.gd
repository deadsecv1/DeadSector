extends Panel

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const ItemIconScene := preload("res://scenes/ItemIcon.tscn")
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

# --- Left: mini battle pass tier track ---
@onready var tickets_label: Label = $VBox/HBox/LeftCol/TicketsLabel
@onready var tier_label: Label = $VBox/HBox/LeftCol/TierLabel
@onready var progress_bar: ProgressBar = $VBox/HBox/LeftCol/ProgressBar
@onready var skip_button: Button = $VBox/HBox/LeftCol/SkipButton
@onready var tier_list: VBoxContainer = $VBox/HBox/LeftCol/TierScroll/TierList

# --- Middle: 5 egg slots ---
@onready var egg_slots_row: HBoxContainer = $VBox/HBox/MiddleCol/EggSlotsRow
@onready var hatch_particles: Control = $VBox/HBox/MiddleCol/HatchParticles
@onready var my_pets_button: Button = $VBox/HBox/MiddleCol/MyPetsButton

# --- Right: hatchery deposit list ---
@onready var graveyard_button: Button = $VBox/HBox/RightCol/GraveyardButton
@onready var right_list: VBoxContainer = $VBox/HBox/RightCol/ListScroll/RightList

@onready var close_button: Button = $VBox/CloseButton

signal my_pets_requested
signal graveyard_requested

func _ready() -> void:
	visible = false
	# Full-screen panel (fills the whole viewport) - no draggable edges here, unlike the smaller centered popups.
	close_button.pressed.connect(func(): closed.emit())
	skip_button.pressed.connect(_on_skip)
	my_pets_button.pressed.connect(func(): my_pets_requested.emit())
	graveyard_button.pressed.connect(func(): graveyard_requested.emit())
	hatch_particles.set_script(load("res://scripts/TooltipParticles.gd"))
	# Same known Godot quirk as PlushiePetReveal.gd - attaching a script
	# to an already-in-tree node drops process callbacks even though
	# the script's own _ready() calls set_process(true).
	hatch_particles.set_process(true)
	set_process(true)

func open() -> void:
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()

func _process(_delta: float) -> void:
	if visible:
		_refresh_egg_slots()

func refresh() -> void:
	tickets_label.text = "Tickets: %d" % GameManager.salvaged_beasts_tickets
	tier_label.text = "Tier %d / %d" % [GameManager.salvaged_beasts_tier, GameManager.SALVAGED_BEASTS_MAX_TIER]
	if GameManager.salvaged_beasts_tier >= GameManager.SALVAGED_BEASTS_MAX_TIER:
		progress_bar.value = 1.0
		skip_button.disabled = true
	else:
		var needed := 60 + GameManager.salvaged_beasts_tier * 12
		progress_bar.max_value = float(needed)
		progress_bar.value = float(GameManager.salvaged_beasts_progress)
		skip_button.disabled = GameManager.salvaged_beasts_tickets < 40
	skip_button.text = "Skip Tier (40 Tickets)"

	for c in tier_list.get_children():
		c.queue_free()
	var rewards: Array = GameManager._generate_salvaged_beasts_rewards()
	for i in range(rewards.size()):
		tier_list.add_child(_make_tier_row(i + 1, rewards[i]))

	for c in right_list.get_children():
		c.queue_free()
	_build_egg_list()

	_refresh_egg_slots()

func _make_tier_row(tier: int, reward: Dictionary) -> Control:
	var unlocked: bool = tier <= GameManager.salvaged_beasts_tier
	var is_current: bool = tier == GameManager.salvaged_beasts_tier + 1
	var accent: Color = _reward_accent_color(reward)

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.18, 0.85) if unlocked else Color(0.08, 0.08, 0.08, 0.6)
	sb.border_color = accent if (unlocked or is_current) else Color(0.3, 0.3, 0.3, 0.5)
	sb.set_border_width_all(2 if is_current else 1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var tier_lbl := Label.new()
	tier_lbl.text = "T%d" % tier
	tier_lbl.custom_minimum_size = Vector2(34, 0)
	tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 12)
	tier_lbl.modulate = Color(1, 0.75, 0.4, 1) if unlocked else (Color(1, 1, 1, 0.9) if is_current else Color(1, 1, 1, 0.4))
	hbox.add_child(tier_lbl)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(28, 28)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := _make_reward_icon(reward, accent)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_box.add_child(icon)
	hbox.add_child(icon_box)

	var desc_lbl := Label.new()
	desc_lbl.text = _describe_reward(reward)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_color_override("font_color", accent if unlocked else Color(1, 1, 1, 0.5))
	hbox.add_child(desc_lbl)

	if unlocked:
		var check_lbl := Label.new()
		check_lbl.text = "claimed"
		check_lbl.add_theme_font_size_override("font_size", 10)
		check_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
		hbox.add_child(check_lbl)
	elif is_current:
		var next_lbl := Label.new()
		next_lbl.text = "NEXT"
		next_lbl.add_theme_font_size_override("font_size", 10)
		next_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1))
		hbox.add_child(next_lbl)

	return row

# A consistent accent color per reward - rarity color for eggs/items,
# a fixed currency tone for Rubles/Tickets - used for both the icon
# tint and the row's border/background.
func _reward_accent_color(reward: Dictionary) -> Color:
	match reward.get("type", ""):
		"egg":
			return GameManager.get_rarity_color(str(reward.get("rarity", "common")))
		"item":
			return GameManager.get_rarity_color(str(reward.get("item", {}).get("rarity", "common")))
		"rubles":
			return Color(0.85, 0.75, 0.35, 1)
		"tickets":
			return Color(0.95, 0.8, 0.3, 1)
		_:
			return Color(0.8, 0.8, 0.8, 1)

# A real icon per reward type instead of plain text - eggs and gear use
# their actual item icon, Tickets uses the small currency icon set.
func _make_reward_icon(reward: Dictionary, accent: Color) -> Control:
	match reward.get("type", ""):
		"egg":
			var icon = ItemIconScene.instantiate()
			icon.icon_key = "egg"
			icon.icon_color = accent
			return icon
		"item":
			var icon = ItemIconScene.instantiate()
			icon.icon_key = str(reward.get("item", {}).get("icon_key", "generic"))
			icon.icon_color = accent
			return icon
		"rubles":
			var icon = ItemIconScene.instantiate()
			icon.icon_key = "rubles_item"
			icon.icon_color = accent
			return icon
		"tickets":
			var icon = SmallIconScene.instantiate()
			icon.icon_type = "money"
			icon.icon_bg = Color(accent.r * 0.3, accent.g * 0.3, accent.b * 0.3, 1)
			return icon
		_:
			var icon = ItemIconScene.instantiate()
			icon.icon_key = "generic"
			icon.icon_color = accent
			return icon

func _describe_reward(reward: Dictionary) -> String:
	match reward.get("type", ""):
		"egg": return "%s Egg" % GameManager.get_rarity_label(reward.get("rarity", "common"))
		"tickets": return "%d Tickets" % int(reward.get("amount", 0))
		"rubles": return "%d Rubles" % int(reward.get("amount", 0))
		"item": return str(reward.get("item", {}).get("name", "Exclusive Item"))
		_: return "Reward"

func _build_egg_list() -> void:
	if GameManager.pet_eggs.is_empty():
		var lbl := Label.new()
		var stash_egg_count := 0
		for stash_item in GameManager.stash_items:
			if stash_item.get("slot", "") == "egg":
				stash_egg_count += 1
		if stash_egg_count > 0:
			# Shouldn't really happen anymore - Eggs deposit here
			# automatically now - but covers older saves right up until
			# their next load finishes migrating them over.
			lbl.text = "You have %d Egg%s about to move here automatically - reopen this screen in a moment." % [stash_egg_count, "" if stash_egg_count == 1 else "s"]
		else:
			lbl.text = "No Eggs yet - find them in raids or the Bloodline Gauntlet. They'll show up here automatically, ready to hatch - no need to dig them out of your Stash."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		right_list.add_child(lbl)
		return
	for i in range(GameManager.pet_eggs.size()):
		right_list.add_child(_make_egg_row(i))

func _make_egg_row(index: int) -> Control:
	var egg: Dictionary = GameManager.pet_eggs[index]
	var rarity: String = egg.get("rarity", "common")
	var rarity_color := GameManager.get_rarity_color(rarity)
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 50)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.06, 0.02, 0.85)
	sb.border_color = rarity_color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	row.add_theme_stylebox_override("panel", sb)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	var icon = ItemIconScene.instantiate()
	icon.icon_key = "egg"
	icon.icon_color = rarity_color
	icon.custom_minimum_size = Vector2(32, 32)
	hbox.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = egg.get("name", "Egg")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	hbox.add_child(name_lbl)
	var hatch_btn := Button.new()
	hatch_btn.text = "Hatch"
	hatch_btn.custom_minimum_size = Vector2(70, 0)
	hatch_btn.disabled = GameManager.egg_hatching_slots.size() >= GameManager.MAX_HATCH_SLOTS
	hatch_btn.pressed.connect(func():
		if GameManager.start_hatching_egg(index):
			refresh()
	)
	hbox.add_child(hatch_btn)
	return row

# --- The 5 egg slots in the middle: shows a real egg icon that visibly
# cracks (via a shrinking "whole" overlay revealing a "cracked" state
# underneath) as the hatch timer counts down, then the collect prompt.
func _refresh_egg_slots() -> void:
	var slot_count: int = GameManager.MAX_HATCH_SLOTS
	if egg_slots_row.get_child_count() != slot_count:
		for c in egg_slots_row.get_children():
			c.queue_free()
		for i in range(slot_count):
			egg_slots_row.add_child(_make_egg_slot())
	for i in range(slot_count):
		_update_egg_slot(egg_slots_row.get_child(i), i)

func _make_egg_slot() -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(84, 100)
	box.name = "EggSlot"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.03, 0.7)
	sb.set_corner_radius_all(6)
	box.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	box.add_child(vbox)

	var icon_slot := Control.new()
	icon_slot.name = "IconSlot"
	icon_slot.custom_minimum_size = Vector2(0, 56)
	icon_slot.clip_contents = true
	vbox.add_child(icon_slot)

	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = 1.0
	bar.show_percentage = false
	vbox.add_child(bar)

	var status := Label.new()
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 10)
	vbox.add_child(status)

	var btn := Button.new()
	btn.name = "ActionButton"
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override("font_size", 10)
	vbox.add_child(btn)

	return box

func _update_egg_slot(box: Control, index: int) -> void:
	var vbox: VBoxContainer = box.get_node("VBox")
	var icon_slot: Control = vbox.get_node("IconSlot")
	var bar: ProgressBar = vbox.get_node("Bar")
	var status: Label = vbox.get_node("Status")
	var btn: Button = vbox.get_node("ActionButton")

	if not btn.pressed.is_connected(_on_slot_button):
		btn.pressed.connect(_on_slot_button.bind(index))

	if index >= GameManager.egg_hatching_slots.size():
		# Empty slot - nothing hatching here right now.
		for c in icon_slot.get_children():
			c.queue_free()
		var placeholder := Label.new()
		placeholder.text = "Empty"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.anchor_right = 1.0
		placeholder.anchor_bottom = 1.0
		placeholder.modulate = Color(1, 1, 1, 0.35)
		icon_slot.add_child(placeholder)
		bar.value = 0.0
		status.text = ""
		btn.visible = false
		return

	var slot_data: Dictionary = GameManager.egg_hatching_slots[index]
	var rarity: String = slot_data.get("rarity", "common")
	var rarity_color := GameManager.get_rarity_color(rarity)
	var progress: float = GameManager.get_hatching_progress(index)
	bar.value = progress
	bar.modulate = rarity_color

	for c in icon_slot.get_children():
		c.queue_free()
	var icon = ItemIconScene.instantiate()
	icon.icon_key = "egg"
	icon.icon_color = rarity_color
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0
	icon_slot.add_child(icon)
	# The crack: a dark overlay wipes away from the top as progress
	# climbs, so the egg visibly "opens" instead of just a bar filling.
	if progress < 1.0:
		var crack_overlay := ColorRect.new()
		crack_overlay.color = Color(0.02, 0.02, 0.02, 0.55)
		crack_overlay.anchor_left = 0.0
		crack_overlay.anchor_right = 1.0
		crack_overlay.anchor_top = 0.0
		crack_overlay.anchor_bottom = progress
		crack_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_slot.add_child(crack_overlay)
		for line_i in range(3):
			var t: float = float(line_i) / 3.0
			if t > progress:
				continue
			var crack_line := ColorRect.new()
			crack_line.color = Color(0.05, 0.05, 0.05, 0.8)
			crack_line.anchor_left = 0.3 + line_i * 0.15
			crack_line.anchor_right = 0.32 + line_i * 0.15
			crack_line.anchor_top = 0.0
			crack_line.anchor_bottom = 1.0
			crack_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_slot.add_child(crack_line)

	if progress < 1.0:
		status.text = "%s Egg" % GameManager.get_rarity_label(rarity)
		btn.visible = false
	else:
		status.text = "Hatched!"
		btn.text = "Collect"
		btn.visible = true

func _on_slot_button(index: int) -> void:
	if index >= GameManager.egg_hatching_slots.size():
		return
	if GameManager.get_hatching_progress(index) < 1.0:
		return
	var instance_id := GameManager.collect_hatched_egg(index)
	if instance_id == "":
		return
	var data := GameManager.get_pet_data(instance_id)
	Sfx.play_reveal()
	GameManager.toast_requested.emit("Hatched %s!" % data.get("name", "a pet"))
	refresh()

func _on_skip() -> void:
	if GameManager.skip_salvaged_beasts_tier():
		refresh()
	else:
		GameManager.toast_requested.emit("Not enough Tickets to skip a tier")
