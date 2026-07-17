extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

# A shared overlay both RaidRewards.gd (successful extraction) and
# DeathScreen.gd (death/abandon) instance identically - reads
# GameManager.last_raid_breakdown (snapshotted by end_run() right before
# it clears the live per-raid logs), so it works the same regardless of
# how the raid ended.

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

@onready var vbox: VBoxContainer = $VBox
@onready var kills_list: VBoxContainer = $VBox/Columns/KillsColumn/KillsScroll/KillsList
@onready var damage_list: VBoxContainer = $VBox/Columns/DamageColumn/DamageScroll/DamageList
@onready var kills_empty_label: Label = $VBox/Columns/KillsColumn/KillsEmptyLabel
@onready var damage_empty_label: Label = $VBox/Columns/DamageColumn/DamageEmptyLabel
@onready var graph: Control = $VBox/GraphPanel/NetWorthGraph
@onready var summary_label: Label = $VBox/SummaryLabel
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	# self is a full-screen backdrop wrapper (see PostRaidBreakdownPanel.tscn)
	# with no offsets of its own (anchor 0/0/1/1, offset 0/0/0/0) - bounds
	# just scopes the drag HITBOX to vbox's rect instead of the whole
	# screen's edges; dragging still moves self (backdrop + content
	# together) as one cohesive unit. See DraggablePanel.apply()'s own
	# comment.
	DraggablePanelScript.apply(self, vbox)
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	# Undo any leftover drag from a previous time this same instance was
	# open - see LorePanel.gd's open() for the same fix and full reasoning
	# (self's authored position is (0,0), NOT a value captured at
	# _ready() time, which can read back wrong before the first real
	# layout pass resolves).
	position = Vector2.ZERO
	refresh()
	GameManager.focus_first_control(self)
	PanelOpenFX.animate_open(self)

func refresh() -> void:
	var data: Dictionary = GameManager.last_raid_breakdown
	var kills: Array = data.get("kills", [])
	var damage_taken: Array = data.get("damage_taken", [])
	var value_samples: Array = data.get("value_samples", [])

	var total_damage := 0
	for hit in damage_taken:
		total_damage += int(hit.get("amount", 0))
	summary_label.text = "%d kill%s  ·  %d hit%s taken (%d total damage)" % [
		kills.size(), "" if kills.size() == 1 else "s",
		damage_taken.size(), "" if damage_taken.size() == 1 else "s", total_damage,
	]

	for c in kills_list.get_children():
		c.queue_free()
	kills_empty_label.visible = kills.is_empty()
	for entry in kills:
		kills_list.add_child(_make_kill_row(entry))

	for c in damage_list.get_children():
		c.queue_free()
	damage_empty_label.visible = damage_taken.is_empty()
	for entry in damage_taken:
		damage_list.add_child(_make_damage_row(entry))

	graph.set_samples(value_samples)

func _format_time(t: float) -> String:
	var total := int(t)
	return "%d:%02d" % [total / 60, total % 60]

func _make_kill_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var time_lbl := Label.new()
	time_lbl.text = _format_time(float(entry.get("time", 0.0)))
	time_lbl.custom_minimum_size = Vector2(46, 0)
	time_lbl.add_theme_font_size_override("font_size", 12)
	time_lbl.modulate = Color(1, 1, 1, 0.6)
	row.add_child(time_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "%s (%s)" % [str(entry.get("enemy", "Enemy")), str(entry.get("weapon", "Unarmed"))]
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
	row.add_child(desc_lbl)

	return row

func _make_damage_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var time_lbl := Label.new()
	time_lbl.text = _format_time(float(entry.get("time", 0.0)))
	time_lbl.custom_minimum_size = Vector2(46, 0)
	time_lbl.add_theme_font_size_override("font_size", 12)
	time_lbl.modulate = Color(1, 1, 1, 0.6)
	row.add_child(time_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "-%d %s from %s (%s)" % [int(entry.get("amount", 0)), str(entry.get("body_part", "Thorax")), str(entry.get("attacker", "Unknown")), str(entry.get("weapon", "Unknown"))]
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.95, 0.5, 0.45, 1))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(desc_lbl)

	return row
