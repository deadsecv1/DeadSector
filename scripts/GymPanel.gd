extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

const UPGRADE_ORDER := ["gym_health", "gym_speed", "gym_damage", "gym_regen", "gym_reload"]
const UPGRADE_ICONS := {
	"gym_health": "medical", "gym_speed": "stealth", "gym_damage": "combat",
	"gym_regen": "medical", "gym_reload": "gear",
}
const SmallIconScene := preload("res://scenes/SmallIcon.tscn")

@onready var alloys_label: Label = $VBox/AlloysLabel
@onready var upgrade_list: VBoxContainer = $VBox/ListScroll/UpgradeList
@onready var close_button: Button = $VBox/CloseButton

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

func _ready() -> void:
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())
	visible = false

func open() -> void:
	visible = true
	refresh()
	GameManager.focus_first_control(self)
	PanelOpenFX.animate_open(self)

func refresh() -> void:
	alloys_label.text = "Alloys: %d" % GameManager.alloys
	for c in upgrade_list.get_children():
		c.queue_free()
	for key in UPGRADE_ORDER:
		upgrade_list.add_child(_make_row(key))

func _make_row(key: String) -> Control:
	var u: Dictionary = GameManager.hideout_upgrades[key]
	var level: int = int(u.get("level", 0))
	var max_level: int = int(u.get("max_level", 0))
	var maxed: bool = level >= max_level

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 92)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.16, 0.13, 0.9) if not maxed else Color(0.16, 0.14, 0.08, 0.9)
	sb.border_color = Color(0.5, 0.75, 0.4, 0.7) if not maxed else Color(0.85, 0.7, 0.25, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row.add_child(hbox)

	var icon = SmallIconScene.instantiate()
	icon.icon_type = UPGRADE_ICONS.get(key, "gear")
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)

	var name_lbl := Label.new()
	name_lbl.text = str(u.get("label", key))
	name_lbl.add_theme_font_size_override("font_size", 18)
	info.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = str(u.get("desc", ""))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.modulate = Color(1, 1, 1, 0.75)
	info.add_child(desc_lbl)

	var pip_row := HBoxContainer.new()
	pip_row.add_theme_constant_override("separation", 4)
	for i in range(max_level):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 8)
		pip.color = Color(0.55, 0.85, 0.4, 1) if i < level else Color(1, 1, 1, 0.15)
		pip_row.add_child(pip)
	info.add_child(pip_row)
	hbox.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(130, 60)
	if maxed:
		btn.text = "MAXED"
		btn.disabled = true
	else:
		var cost: int = GameManager.get_hideout_upgrade_cost(key)
		btn.text = "Train\n%d Alloys" % cost
		btn.disabled = not GameManager.can_afford_hideout_upgrade(key)
		btn.pressed.connect(_on_buy.bind(key))
	hbox.add_child(btn)

	return row

func _on_buy(key: String) -> void:
	GameManager.purchase_hideout_upgrade(key)
	refresh()
