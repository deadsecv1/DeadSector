extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		closed.emit()

const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

@onready var particles: Control = $Particles
@onready var list: VBoxContainer = $VBox/Scroll/List
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var close_button: Button = $VBox/CloseButton

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	particles.set_script(load("res://scripts/TooltipParticles.gd"))
	# Same known Godot quirk as PlushiePetReveal.gd - attaching a script
	# to an already-in-tree node drops process callbacks even though
	# the script's own _ready() calls set_process(true).
	particles.set_process(true)
	particles.particle_color = Color(1.0, 0.85, 0.4, 1)
	particles.intensity = 26
	close_button.pressed.connect(func(): closed.emit())

func open() -> void:
	visible = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if particles.has_method("_init_particles"):
		particles._init_particles()
	refresh()

func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	var ids: Array = GameManager.ACHIEVEMENTS.keys()
	var unlocked_count := 0
	for id in ids:
		if GameManager.unlocked_achievements.has(id):
			unlocked_count += 1
	progress_label.text = "%d / %d unlocked" % [unlocked_count, ids.size()]
	# Unlocked ones first (most recently unlocked isn't tracked by order,
	# so just group unlocked-before-locked for readability), each sorted
	# alphabetically within its group.
	ids.sort_custom(func(a, b): return GameManager.ACHIEVEMENTS[a].get("name", a) < GameManager.ACHIEVEMENTS[b].get("name", b))
	var unlocked_ids: Array = ids.filter(func(id): return GameManager.unlocked_achievements.has(id))
	var locked_ids: Array = ids.filter(func(id): return not GameManager.unlocked_achievements.has(id))
	for id in unlocked_ids:
		list.add_child(_make_row(id, true))
	for id in locked_ids:
		list.add_child(_make_row(id, false))

func _make_row(id: String, unlocked: bool) -> Control:
	var data: Dictionary = GameManager.ACHIEVEMENTS.get(id, {})
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 68)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.11, 0.04, 0.85) if unlocked else Color(0.08, 0.08, 0.08, 0.7)
	sb.border_color = Color(1.0, 0.85, 0.4, 0.8) if unlocked else Color(0.3, 0.3, 0.3, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(48, 48)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = Color(0.25, 0.2, 0.05, 0.9) if unlocked else Color(0.05, 0.05, 0.05, 0.9)
	icon_sb.set_corner_radius_all(4)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	if unlocked:
		var icon = SmallIconScene.instantiate()
		icon.icon_type = data.get("icon", "star")
		icon.icon_bg = Color(0, 0, 0, 0)
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon_box.add_child(icon)
	else:
		var q := Label.new()
		q.text = "?"
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.add_theme_font_size_override("font_size", 22)
		q.modulate = Color(1, 1, 1, 0.4)
		icon_box.add_child(q)
	hbox.add_child(icon_box)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	var name_lbl := Label.new()
	name_lbl.text = str(data.get("name", id))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1) if unlocked else Color(0.7, 0.7, 0.7, 1))
	info.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = str(data.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.modulate = Color(1, 1, 1, 0.75 if unlocked else 0.5)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	var status_lbl := Label.new()
	status_lbl.custom_minimum_size = Vector2(110, 0)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 11)
	if unlocked:
		status_lbl.text = "Unlocked\n%s" % str(GameManager.unlocked_achievements.get(id, ""))
		status_lbl.modulate = Color(0.6, 0.9, 0.6, 1)
	else:
		status_lbl.text = "Locked"
		status_lbl.modulate = Color(1, 1, 1, 0.4)
	hbox.add_child(status_lbl)

	return row
