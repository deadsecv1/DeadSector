extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		if detail_view.visible:
			_show_list()
		else:
			closed.emit()

@onready var vbox: VBoxContainer = $VBox
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var list_scroll: ScrollContainer = $VBox/ListScroll
@onready var list: VBoxContainer = $VBox/ListScroll/List
@onready var detail_view: Control = $VBox/DetailView
@onready var detail_title: Label = $VBox/DetailView/DetailTitle
@onready var detail_location: Label = $VBox/DetailView/DetailLocation
@onready var detail_text: Label = $VBox/DetailView/DetailText
@onready var back_button: Button = $VBox/DetailView/BackButton
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	# self is a full-screen backdrop wrapper (see LorePanel.tscn) with no
	# offsets of its own (anchor 0/0/1/1, offset 0/0/0/0) - bounds just
	# scopes the drag HITBOX to vbox's rect instead of the whole screen's
	# edges; dragging still moves self (backdrop + content together) as
	# one cohesive unit. See DraggablePanel.apply()'s own comment.
	DraggablePanelScript.apply(self, vbox)
	close_button.pressed.connect(func(): closed.emit())
	back_button.pressed.connect(_show_list)

func open() -> void:
	visible = true
	# Undo any leftover drag from a previous time this same instance was
	# open. self's authored position is (0,0) (full-rect anchors, zero
	# offsets, per LorePanel.tscn) - NOT captured at _ready() time, since
	# a Control's .position can read back wrong before its first real
	# layout pass resolves (this bit LorePanel/PostRaidBreakdownPanel
	# once already: capturing vbox.position in _ready() sometimes
	# captured a pre-layout (0,0)-ish value instead of vbox's real
	# centered position, making the panel open pinned to the top-left).
	position = Vector2.ZERO
	# Separately, vbox's own anchors/offsets can ALSO read back as their
	# un-set defaults (0,0,0,0) instead of the .tscn-designed centered
	# values - the same project-wide gotcha SeasonPassPanel/GuildPanel
	# already guard against (see CLAUDE.md). Missing this half of the fix
	# here is exactly what let the panel keep opening cropped/off-position
	# even after the drag-drift half was fixed - force it explicitly too.
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -320.0
	vbox.offset_top = -290.0
	vbox.offset_right = 320.0
	vbox.offset_bottom = 290.0
	_show_list()
	GameManager.focus_first_control(self)
	PanelOpenFX.animate_open(self)

func _show_list() -> void:
	detail_view.visible = false
	list_scroll.visible = true
	refresh()
	GameManager.focus_first_control(self)

func refresh() -> void:
	var entries: Array = GameManager.LORE_ENTRIES
	var found_count := 0
	for entry in entries:
		if GameManager.is_lore_object_found(entry.get("id", "")):
			found_count += 1
	progress_label.text = "%d / %d Found" % [found_count, entries.size()]

	for c in list.get_children():
		c.queue_free()
	for entry in entries:
		list.add_child(_make_row(entry))

func _make_row(entry: Dictionary) -> Control:
	var lore_id: String = entry.get("id", "")
	var found: bool = GameManager.is_lore_object_found(lore_id)

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.1, 0.2, 0.85) if found else Color(0.08, 0.08, 0.09, 0.7)
	sb.border_color = Color(0.68, 0.5, 0.98, 0.85) if found else Color(0.3, 0.3, 0.3, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	var title_lbl := Label.new()
	title_lbl.text = str(entry.get("title", "?")) if found else "??? Undiscovered"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color(0.78, 0.65, 1.0, 1) if found else Color(0.6, 0.6, 0.6, 1))
	info.add_child(title_lbl)
	var loc_lbl := Label.new()
	loc_lbl.text = str(entry.get("location", "")) if found else "Somewhere in the Sector."
	loc_lbl.add_theme_font_size_override("font_size", 12)
	loc_lbl.modulate = Color(1, 1, 1, 0.7 if found else 0.45)
	info.add_child(loc_lbl)
	hbox.add_child(info)

	if found:
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_show_detail(entry)
		)

	return row

func _show_detail(entry: Dictionary) -> void:
	list_scroll.visible = false
	detail_view.visible = true
	detail_title.text = str(entry.get("title", "?"))
	detail_location.text = "Found at: %s" % str(entry.get("location", "?"))
	detail_text.text = str(entry.get("text", ""))
	GameManager.focus_first_control(self)
