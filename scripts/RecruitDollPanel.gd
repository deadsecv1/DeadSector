extends Panel
const DraggablePanelScript := preload("res://scripts/DraggablePanel.gd")

signal closed

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo or event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_UP and event.pressed):
		get_viewport().set_input_as_handled()
		closed.emit()

const SLOT_ORDER := ["head", "body", "weapon", "accessory", "boots"]

@onready var title_label: Label = $VBox/TitleLabel
@onready var portrait: Control = $VBox/DollRow/PortraitBox/Portrait
@onready var doll: Control = $VBox/DollRow/Doll
@onready var slot_list: VBoxContainer = $VBox/DollRow/SlotList
@onready var stats_label: Label = $VBox/StatsLabel
@onready var close_button: Button = $VBox/CloseButton

var recruit_id: String = "clarity"
var slot_buttons: Dictionary = {}

func _ready() -> void:
	visible = false
	DraggablePanelScript.apply(self)
	close_button.pressed.connect(func(): closed.emit())

func open_for(rid: String) -> void:
	recruit_id = rid
	visible = true
	_build_slots()
	refresh()
	GameManager.focus_first_control(self)

func _build_slots() -> void:
	GameManager.cancel_gamepad_hold_if_within(slot_list)
	for c in slot_list.get_children():
		c.queue_free()
	slot_buttons.clear()
	for slot in SLOT_ORDER:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var lbl := Label.new()
		lbl.text = slot.capitalize()
		lbl.custom_minimum_size = Vector2(70, 0)
		lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(56, 56)
		btn.set_script(load("res://scripts/RecruitEquipSlot.gd"))
		btn.slot_name = slot
		btn.recruit_id = recruit_id
		btn.changed.connect(refresh)
		row.add_child(btn)

		slot_list.add_child(row)
		slot_buttons[slot] = btn

func refresh() -> void:
	var data: Dictionary = GameManager.RECRUITS.get(recruit_id, {})
	title_label.text = str(data.get("label", recruit_id))
	title_label.add_theme_color_override("font_color", Color(data.get("color", Color.WHITE)).lightened(0.35))
	portrait.trader_id = recruit_id
	portrait.queue_redraw()
	doll.recruit_color = data.get("color", Color(0.4, 0.4, 0.4, 1))
	doll.doll_scale = 1.0 if recruit_id != "big_crax" else 1.25
	doll.queue_redraw()

	var equipment: Dictionary = GameManager.recruit_equipment.get(recruit_id, {})
	for slot in SLOT_ORDER:
		var btn = slot_buttons.get(slot)
		if btn == null:
			continue
		var item = equipment.get(slot)
		btn.recruit_id = recruit_id
		btn.current_item = item
		for child in btn.get_children():
			child.queue_free()
		if item == null:
			btn.text = "Empty"
		else:
			btn.text = ""
			var icon_scene := preload("res://scenes/ItemIcon.tscn")
			var icon = icon_scene.instantiate()
			icon.icon_key = item.get("icon_key", "generic")
			icon.icon_color = GameManager.get_rarity_color(item.get("rarity", "common"))
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			icon.offset_left = 3
			icon.offset_top = 3
			icon.offset_right = -3
			icon.offset_bottom = -3
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(icon)
			var gradient_border = GameManager.make_gradient_border(item.get("rarity", ""))
			if gradient_border != null:
				btn.add_child(gradient_border)
				btn.move_child(gradient_border, 0)
				var slot_bg := ColorRect.new()
				slot_bg.color = Color(0.12, 0.14, 0.13, 0.95)
				slot_bg.anchor_right = 1.0
				slot_bg.anchor_bottom = 1.0
				slot_bg.offset_left = 3
				slot_bg.offset_top = 3
				slot_bg.offset_right = -3
				slot_bg.offset_bottom = -3
				slot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
				btn.add_child(slot_bg)
				btn.move_child(slot_bg, 1)

	var dmg_bonus: float = GameManager.get_recruit_bonus(recruit_id, "damage")
	var speed_bonus: float = GameManager.get_recruit_bonus(recruit_id, "speed")
	stats_label.text = "Base Damage: %d (+%d equipped)\nMove Speed: 235 (+%d equipped)\nCost to Bring: %d Rubles" % [
		int(data.get("base_damage", 14)), int(dmg_bonus), int(speed_bonus), int(data.get("cost", 0))
	]
